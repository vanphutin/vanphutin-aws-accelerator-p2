<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>${site_title}</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: ${bg_color};
            color: #ffffff;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .card {
            background: rgba(0, 0, 0, 0.4);
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            text-align: center;
            border: 1px solid rgba(255,255,255,0.1);
        }
        h1 { margin-top: 0; font-size: 2.5rem; }
        p { font-size: 1.2rem; opacity: 0.9; }
        .badge {
            background: #ffffff;
            color: #1e293b;
            padding: 6px 16px;
            border-radius: 20px;
            font-weight: bold;
            display: inline-block;
            margin-top: 15px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>${welcome_message}</h1>
        <p>Chào mừng <strong>${admin_name}</strong> đã ghé thăm trang web!</p>
        <p>Website này được khởi tạo động qua Child Module & for_each.</p>
        <span class="badge">Port: ${port}</span>
    </div>
</body>
</html>