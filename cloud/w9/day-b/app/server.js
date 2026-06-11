const express = require('express');
const { context, trace, SpanStatusCode } = require('@opentelemetry/api');
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { MeterProvider } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const SERVICE_NAME = process.env.SERVICE_NAME || 'api-service';
const PORT = Number(process.env.PORT || 8080);
const METRICS_PORT = Number(process.env.METRICS_PORT || 9464);
const OTLP_TRACES_URL = process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || 'http://localhost:4318/v1/traces';

const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'local-dev',
});

// TracerProvider gửi span sang OTel Collector bằng OTLP HTTP.
const tracerProvider = new NodeTracerProvider({ resource });
tracerProvider.addSpanProcessor(new BatchSpanProcessor(new OTLPTraceExporter({ url: OTLP_TRACES_URL })));
tracerProvider.register();
const tracer = trace.getTracer(SERVICE_NAME);

// PrometheusExporter mở endpoint /metrics riêng để Prometheus scrape.
const prometheusExporter = new PrometheusExporter({ port: METRICS_PORT, endpoint: '/metrics' });
const meterProvider = new MeterProvider({ resource });
meterProvider.addMetricReader(prometheusExporter);
const meter = meterProvider.getMeter(SERVICE_NAME);

const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Tổng số HTTP request theo route, method và status_code',
});

const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'Độ trễ HTTP request theo giây',
  unit: 's',
});

const app = express();
app.use(express.json());

function activeTraceFields() {
  const span = trace.getActiveSpan();
  if (!span) {
    return { trace_id: undefined, span_id: undefined };
  }
  const spanContext = span.spanContext();
  return { trace_id: spanContext.traceId, span_id: spanContext.spanId };
}

function log(level, message, fields = {}) {
  const line = {
    timestamp: new Date().toISOString(),
    level,
    service: SERVICE_NAME,
    ...activeTraceFields(),
    message,
    ...fields,
  };
  console.log(JSON.stringify(line));
}

function recordMetrics(route, method, statusCode, durationSeconds) {
  const labels = {
    namespace: 'platform',
    service: SERVICE_NAME,
    route,
    method,
    status_code: String(statusCode),
  };
  requestCounter.add(1, labels);
  requestDuration.record(durationSeconds, labels);
}

function withRouteSpan(name, route, handler) {
  return async (req, res) => {
    const span = tracer.startSpan(name, {
      attributes: {
        'http.method': req.method,
        'http.route': route,
        'service.name': SERVICE_NAME,
      },
    });
    const started = process.hrtime.bigint();

    await context.with(trace.setSpan(context.active(), span), async () => {
      try {
        await handler(req, res, span);
        span.setAttribute('http.status_code', res.statusCode);
        span.setStatus({ code: SpanStatusCode.OK });
      } catch (error) {
        const statusCode = error.statusCode || 500;
        span.recordException(error);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        res.status(statusCode).json({ error: error.message, service: SERVICE_NAME });
        log('error', error.message, { route, status_code: statusCode });
      } finally {
        const elapsed = Number(process.hrtime.bigint() - started) / 1e9;
        recordMetrics(route, req.method, res.statusCode, elapsed);
        span.end();
      }
    });
  };
}

app.get('/health', (req, res) => {
  res.setHeader('x-service-version', process.env.SERVICE_VERSION || 'stable');
  res.json({ status: 'ok', service: SERVICE_NAME });
});

app.get('/api/orders', withRouteSpan('GET /api/orders', '/api/orders', async (req, res, span) => {
  span.setAttribute('app.operation', 'orders.list');
  if (Math.random() < 0.1) {
    const error = new Error('simulated order lookup failure');
    error.statusCode = 500;
    throw error;
  }
  const orders = [
    { id: 'ord-1001', total: 49.99, currency: 'USD', status: 'paid' },
    { id: 'ord-1002', total: 19.5, currency: 'USD', status: 'pending' },
  ];
  log('info', 'listed orders', { order_count: orders.length });
  res.setHeader('x-service-version', process.env.SERVICE_VERSION || 'stable');
  res.json({ orders });
}));

app.post('/api/orders', withRouteSpan('POST /api/orders', '/api/orders', async (req, res, span) => {
  span.setAttribute('app.operation', 'orders.create');
  if (Math.random() < 0.1) {
    const error = new Error('simulated order creation failure');
    error.statusCode = 500;
    throw error;
  }
  const order = {
    id: `ord-${Date.now()}`,
    total: Number(req.body.total || 25),
    currency: req.body.currency || 'USD',
    status: 'accepted',
  };
  log('info', 'created order', { order_id: order.id, total: order.total });
  res.setHeader('x-service-version', process.env.SERVICE_VERSION || 'stable');
  res.status(201).json({ order });
}));

app.listen(PORT, () => {
  log('info', 'api-service started', {
    port: PORT,
    metrics_port: METRICS_PORT,
    otlp_traces_url: OTLP_TRACES_URL,
  });
});
