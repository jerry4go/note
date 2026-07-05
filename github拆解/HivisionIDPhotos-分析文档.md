# HivisionIDPhotos 工程拆解分析

> 项目地址：https://github.com/Zeyi-Lin/HivisionIDPhotos

---

## 一、项目定位

轻量级 AI 证件照制作系统。输入一张照片，自动完成：

1. 人像抠图
2. 人脸检测 + 旋转对齐
3. 智能裁剪（按证件照规格定位头部位置）
4. 换底色（纯色 / 渐变 / 图片背景）
5. 生成标准证件照、高清照、六寸排版照

---

## 二、技术栈

| 层          | 技术                                            |
| ---------- | --------------------------------------------- |
| **推理引擎**   | ONNX Runtime（CPU / CUDA GPU）、MNN（移动端，可选）      |
| **抠图模型**   | MODNet（25MB）、RMBG-1.4（176MB）、BiRefNet（224MB）  |
| **人脸检测**   | MTCNN（离线，毫秒级）、RetinaFace（离线，秒级）、Face++（在线API） |
| **图像处理**   | OpenCV、NumPy、Pillow                           |
| **Web UI** | Gradio                                        |
| **API 服务** | FastAPI + Uvicorn                             |
| **部署**     | Docker（python:3.10-slim）、Docker Compose       |

---

## 三、项目结构

```
HivisionIDPhotos/
├── app.py                          # Gradio Demo 入口（7860端口）
├── deploy_api.py                   # FastAPI 生产服务（8080端口）
├── inference.py                    # CLI 推理脚本
├── Dockerfile / docker-compose.yml
├── requirements.txt                # 核心依赖（onnxruntime, opencv等）
├── requirements-app.txt            # Web依赖（gradio, fastapi, uvicorn）
│
├── hivision/                       # ★ 核心 Python 包
│   ├── __init__.py                 # 导出 IDCreator 等
│   ├── error.py                    # FaceError / APIError
│   ├── utils.py                    # 换底色、水印、DPI、KB压缩、base64
│   │
│   ├── creator/                    # 核心管线模块
│   │   ├── __init__.py             # IDCreator 类（管线编排）
│   │   ├── context.py              # Params / Context / Result 数据类
│   │   ├── choose_handler.py       # 模型选择分发
│   │   ├── human_matting.py        # MODNet / RMBG / BiRefNet 抠图
│   │   ├── face_detector.py        # MTCNN / RetinaFace / Face++ 检测
│   │   ├── photo_adjuster.py       # 智能裁剪 + 头部定位
│   │   ├── layout_calculator.py    # 排版照（六寸/A4/3R/4R）
│   │   ├── rotation_adjust.py      # 人脸旋转校正
│   │   ├── weights/                # ONNX 模型权重（需手动下载）
│   │   └── retinaface/             # RetinaFace 完整推理实现
│   │
│   └── plugin/
│       ├── beauty/                 # 美颜（美白 / 亮度 / 对比度 / 锐化）
│       ├── watermark.py            # 文字水印
│       └── template/               # 社交媒体模板照
│
├── demo/
│   ├── ui.py                       # Gradio UI 布局（34K）
│   ├── processor.py                # UI 图像处理编排（23K）
│   ├── config.py                   # CSV 配置加载
│   ├── locales.py                  # 多语言支持（中/英/日/韩）
│   └── assets/                     # 标题、尺寸列表、颜色列表
│
├── scripts/
│   └── download_model.py           # 模型权重下载脚本
│
├── docs/                           # API 文档
└── test/                           # 测试
```

---

## 四、核心处理管线

```
                    ┌───────────────┐
                    │   输入图片     │
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │  缩放（max 2000px）
                    └───────┬───────┘
                            │
              ┌─────────────▼─────────────┐
              │  1. 人像抠图                │
              │  MODNet / RMBG / BiRefNet   │
              │  → 输出 4通道 RGBA 透明图    │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │  2. 美颜（可选）            │
              │  美白 / 亮度 / 对比度       │
              │  / 锐化 / 饱和度            │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │  3. 人脸检测 + 对齐         │
              │  MTCNN / RetinaFace / Face++│
              │  → 获取 bbox + 5个关键点    │
              │  → 若 roll_angle > 2° 旋转  │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │  4. 智能裁剪（photo_adjuster）│
              │  参数：                     │
              │  - head_measure_ratio=0.2   │
              │  - head_height_ratio=0.45   │
              │  - head_top_range=(0.12,0.1)│
              │  → 标准照（精确目标尺寸）     │
              │  → 高清照（短边≥600px）      │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │  5. 后处理                  │
              │  - 换底色（纯色/渐变/图片）   │
              │  - 排版照（六寸/A4/3R/4R）   │
              │  - 文字水印                  │
              │  - DPI 设置 / KB 压缩        │
              └─────────────┬─────────────┘
                            │
                    ┌───────▼───────┐
                    │   输出成品      │
                    └───────────────┘
```

---

## 五、关键设计细节

### 5.1 AI 抠图模型

| 模型                       | 大小     | 输入尺寸      | 推理时间（CPU）    | 特点              |
| ------------------------ | ------ | --------- | ------------ | --------------- |
| MODNet (hivision_modnet) | 24.7MB | 512×512   | ~0.2s        | 默认，轻量快速，对纯色底适配好 |
| RMBG-1.4                 | 176MB  | 1024×1024 | ~1-2s        | BRIA AI 开源，质量较好 |
| BiRefNet-v1-lite         | 224MB  | 1024×1024 | ~7s（6.2GB内存） | 精度最高，支持CUDA加速   |

所有模型以 ONNX 格式存储和推理，**运行时无 PyTorch/TensorFlow 依赖**。

### 5.2 野兽模式（Beast Mode）

通过环境变量 `RUN_MODE=beast` 启用。模型 session 缓存到全局变量（`HIVISION_MODNET_SESS` 等），首次推理后不释放内存，后续请求跳过模型加载，适合服务端高并发场景。

### 5.3 人脸检测三种方案

| 方案         | 类型    | 速度    | 精度  | 依赖               |
| ---------- | ----- | ----- | --- | ---------------- |
| MTCNN      | 离线    | 毫秒级   | 中等  | mtcnn-runtime    |
| RetinaFace | 离线    | 秒级    | 较高  | 自带 ONNX 模型       |
| Face++     | 在线API | 取决于网络 | 最高  | 需 API Key/Secret |

### 5.4 智能裁剪算法

不是简单居中，而是基于三个比例参数动态计算：

- `head_measure_ratio`: **人脸面积 / 照片总面积**（默认 0.2）
- `head_height_ratio`: **人脸中心在照片中的纵向位置**（默认 0.45，即略高于正中）
- `head_top_range`: **头顶距照片上沿的距离范围**（max=0.12, min=0.10）

算法会迭代调整裁剪框大小和位置，使最后输出满足上述约束。

---

## 六、三个入口的对比

| 入口                | 命令                     | 端口   | 适用场景       |
| ----------------- | ---------------------- | ---- | ---------- |
| **Gradio Web UI** | `python app.py`        | 7860 | 交互式体验、调试   |
| **FastAPI 服务**    | `python deploy_api.py` | 8080 | 生产集成、前后端分离 |
| **CLI 推理**        | `python inference.py`  | —    | 批量处理、脚本调用  |

### 6.1 FastAPI API 端点

| 端点                        | 方法   | 功能                     |
| ------------------------- | ---- | ---------------------- |
| `/idphoto`                | POST | 完整证件照生成（抠图+检测+裁剪+尺寸调整） |
| `/human_matting`          | POST | 纯人像抠图                  |
| `/add_background`         | POST | 透明图加底色                 |
| `/generate_layout_photos` | POST | 生成排版照                  |
| `/watermark`              | POST | 添加文字水印                 |
| `/set_kb`                 | POST | 压缩到目标KB                |
| `/idphoto_crop`           | POST | 已抠图图片裁剪为证件照尺寸          |

### 6.2 CLI 五种模式

```bash
# 1. 完整证件照制作
python inference.py -t idphoto -i input.jpg -o output.png --height 413 --width 295

# 2. 人像抠图
python inference.py -t human_matting -i input.jpg -o output.png

# 3. 透明图加底色
python inference.py -t add_background -i input.png -o output.jpg -c 4f83ce

# 4. 生成排版照
python inference.py -t generate_layout_photos -i input.jpg -o output.jpg --height 413 --width 295

# 5. 证件照裁剪（从已抠图图片）
python inference.py -t idphoto_crop -i matting.png -o output.png --height 413 --width 295
```

---

## 七、部署方式

### 7.1 本地运行（非 Docker）

```bash
# 1. 安装依赖
pip install -r requirements.txt
pip install -r requirements-app.txt

# 2. 下载模型权重
python scripts/download_model.py --models all

# 3. 启动 Gradio UI
python app.py
# 或启动 API 服务
python deploy_api.py
```

### 7.2 Docker 部署

```bash
# 拉取镜像
docker pull linzeyi/hivision_idphotos

# 运行 Gradio UI
docker run -d -p 7860:7860 linzeyi/hivision_idphotos

# 运行 API
docker run -d -p 8080:8080 linzeyi/hivision_idphotos python3 deploy_api.py
```

### 7.3 环境变量

| 变量                            | 说明                                              |
| ----------------------------- | ----------------------------------------------- |
| `FACE_PLUS_API_KEY`           | Face++ 在线检测 API Key |
| `FACE_PLUS_API_SECRET`        | Face++ 在线检测 Secret                              |
| `RUN_MODE=beast`              | 野兽模式（模型常驻内存）                                    |
| `DEFAULT_LANG=zh\|en\|ko\|ja` | Gradio 默认语言                                     |

---

## 八、性能参考

测试环境：Mac M1 Max 64GB（无 GPU 加速）

| 模型组合                  | 内存占用  | 推理（512×715） | 推理（764×1146） |
| --------------------- | ----- | ----------- | ------------ |
| MODNet + MTCNN        | 410MB | 0.207s      | 0.246s       |
| MODNet + RetinaFace   | 405MB | 0.571s      | 0.971s       |
| BiRefNet + RetinaFace | 6.2GB | 7.063s      | 7.128s       |

BiRefNet 在 NVIDIA GPU（CUDA 12.x, onnxruntime-gpu）下可显著加速。

---

## 九、核心模块职责速览

| 文件                                      | 职责                                                       |
| --------------------------------------- | -------------------------------------------------------- |
| `hivision/creator/__init__.py`          | `IDCreator` 类，编排整个管线（matting → beauty → detect → adjust） |
| `hivision/creator/context.py`           | `Params` / `Context` / `Result` 数据类，管线内部传参               |
| `hivision/creator/choose_handler.py`    | 模型选择分发函数                                                 |
| `hivision/creator/human_matting.py`     | 加载 5 种抠图模型 ONNX 并推理                                      |
| `hivision/creator/face_detector.py`     | MTCNN / RetinaFace / Face++ 三种检测实现                       |
| `hivision/creator/photo_adjuster.py`    | 智能裁剪 + 头部定位 + 尺寸调整                                       |
| `hivision/creator/layout_calculator.py` | 排版照计算                                                    |
| `hivision/creator/rotation_adjust.py`   | 人脸旋转校正                                                   |
| `hivision/utils.py`                     | 换底色、水印、DPI、KB 压缩、base64 工具函数                             |
| `hivision/error.py`                     | 自定义异常（FaceError, APIError）                               |
| `hivision/plugin/beauty/`               | 美颜（美白/亮度/对比度/锐化/饱和度）                                     |
| `demo/ui.py`                            | Gradio UI 布局与事件绑定                                        |
| `demo/processor.py`                     | Gradio 处理编排                                              |
| `demo/locales.py`                       | 多语言字符串（中/英/日/韩）                                          |

---

## 十、模型下载方式

```bash
# 下载所有模型
python scripts/download_model.py --models all

# 下载指定模型
python scripts/download_model.py --models modnet_photographic_portrait_matting

# 或手动下载放入 hivision/creator/weights/
```

各模型权重文件的存放目录为 `hivision/creator/weights/`，RetinaFace 权重在 `hivision/creator/retinaface/weights/`。
