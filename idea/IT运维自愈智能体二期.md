# IT运维自愈智能体 二期生产可用版 完整落地 roadmap

先明确边界：**一期是「验证价值的MVP」（只读诊断、手动输入、影子模式），二期是「能落地干活的生产版」**，核心目标是：从「人工喂告警、AI给建议」升级为「告警自动进、AI自动判、小事自动干、大事喊人来」，同时补上长期记忆，让智能体越用越准。

二期严格遵循「风险可控、小步快跑、价值优先」原则，不搞炫技功能，所有新增能力都直接对应运维真实痛点，总周期约10天，1名运维即可完成。

## 一、二期整体定位与核心验收指标

### 和一期的核心差异

| 维度   | 一期MVP          | 二期生产版                  |
|:---- |:-------------- |:---------------------- |
| 告警输入 | 人工手动粘贴告警文本     | 监控系统自动推送，预处理降噪聚合       |
| 记忆能力 | 仅短期会话记忆，单次任务清空 | 长期向量记忆库，沉淀历史故障经验，越用越准  |
| 执行能力 | 只读分析，只给修复建议    | 低风险故障自动执行修复，高风险人工确认后执行 |
| 结果触达 | Dify页面手动查看     | 钉钉/企业微信自动推送诊断报告+操作卡片   |
| 核心价值 | 验证智能体排障可行性     | 真正替代人工重复劳动，降低运维工作量     |

### 二期核心验收指标

1. 告警全链路自动化：100%监控告警自动进入处理流程，无需人工输入
2. 排障准确率提升：从一期的80%提升至90%以上
3. 低风险故障自愈率：30%常见简单故障自动解决，无需人工介入
4. 单故障平均处理时长：从5分钟压缩至2分钟

## 二、二期必做4大核心模块（按优先级排序）

### 模块1：告警预处理Agent + 监控全量对接（入口自动化，优先级最高）

**解决的问题**：一期需要人工粘贴告警，二期实现监控告警自动流入，同时解决告警风暴问题，减少无效排障。

#### 具体做什么

1. 上线独立的「告警预处理Agent」，负责去重、降噪、连锁告警聚合、优先级分级
2. 全量对接企业现有监控系统（Prometheus/Zabbix/Grafana），告警自动推送
3. 建立分级调度规则：P1/P2自动触发深度排障，P3每日汇总推送

#### 落地步骤

1. **第1步：部署预处理Agent（1天）**
   
   - 在Dify新建Agent应用，粘贴前文提供的预处理系统提示词
   - 开启结构化输出强制校验，模型温度调至0.1，保证聚合规则稳定
   - 配置「调用主排障Agent」的HTTP工具，实现故障组自动调度

2. **第2步：监控系统Webhook对接（1天）**
   
   - 方案A（推荐）：写一层轻量转发脚本（Python 100行以内），接收监控告警，统一格式后调用预处理Agent API
     - 好处：兼容多套监控系统、失败重试、格式标准化，避免告警格式混乱导致Agent解析失败
   - 方案B（极简）：直接在Alertmanager/Zabbix里配置Webhook，指向Dify API
   - 关键配置：告警同时携带「告警名称、服务器IP、告警等级、触发时间、监控值」5个核心字段

3. **第3步：分级调度规则落地（0.5天）**
   
   - P1级：立即触发主排障Agent，同时钉钉推送告警通知
   - P2级：立即触发主排障Agent，结果存入当日告警台账
   - P3级：不触发深度排障，每日18点汇总推送一次
   - 已处理中的故障，后续连锁告警自动归组，不重复触发排障

#### 风控点

- 增加调用频率限制：同一故障10分钟内只触发1次深度排障，避免告警风暴导致模型成本飙升
- 增加失败兜底：预处理Agent异常时，直接降级为原始告警推送人工，不影响正常告警通知

---

### 模块2：长期记忆向量库（智能体核心能力，越用越准）

**解决的问题**：一期智能体每次排障都是“从零开始”，不会复用过往故障经验；二期补上长期记忆，历史踩过的坑、验证过的解决方案，自动复用，准确率持续提升。
这是智能体和传统工作流/脚本的本质区别之一：工作流永远不会自己积累经验，智能体可以。

#### 具体存什么（只存高价值内容，不堆无效文档）

分3个独立知识库，分开召回，互不干扰：

1. **历史故障案例库（价值最高）**
   - 内容格式：`故障现象 + 根因 + 排查步骤 + 修复方案 + 复盘总结`
   - 来源：公司过往半年的故障工单、运维记录
   - 数量：先导入Top 20高频故障，不用贪多，效果最明显
2. **运维标准SOP库**
   - 内容：数据库备份、服务重启、磁盘清理、故障定级等标准操作流程
   - 作用：修复步骤严格对齐公司规范，避免AI给出不符合内部制度的方案
3. **系统架构与依赖关系库**
   - 内容：核心服务上下游依赖、服务器角色、数据库主从关系
   - 作用：聚合连锁告警、判断影响范围时更精准

#### 技术实现（Dify原生支持，零额外开发）

1. **向量库选型**：中小企业用Dify内置的Chroma即可，无需单独部署；数据量大于1000条再升级Qdrant

2. **入库方式**：
   
   - 将整理好的故障案例、SOP保存为Markdown文件
   - 在Dify【知识库】中新建3个知识库，分别上传对应文档，自动切片向量化

3. **关联到主排障Agent**：
   
   - 主排障Agent编排页 → 开启【知识库检索】
   
   - 绑定3个知识库，设置检索模式：「每次排障自动召回最相关的3条历史案例+1条SOP」
   
   - 在系统提示词中补充规则：
     
     > 排障时必须先参考知识库中的历史同类故障与标准SOP，优先使用已验证过的解决方案；若知识库中有完全匹配的案例，直接复用修复步骤，并标注「历史案例参考」。

#### 关键优化技巧

- 故障案例一定要结构化，不要直接粘贴大段聊天记录，模型召回准确率会提升30%以上
- 每次人工处理完故障后，把最终方案补充进知识库，形成「排障→复盘→入库→更准」的正向循环
- 二期先做“检索参考”，不做自动更新，人工审核后再入库，避免错误方案被沉淀

---

### 模块3：低风险自动自愈能力（从“给建议”到“动手干”，严格风控）

**解决的问题**：一期只输出修复建议，还需要人工登录服务器操作；二期对无风险、标准化的操作，开放自动执行权限，真正释放人力。
**核心原则**：只做「绝对安全、可回滚、不影响业务」的操作，高风险操作一律人工确认，宁可不做也不能出错。

#### 操作分级与权限边界（红线必须守）

| 风险等级     | 操作内容                                      | 执行方式               | 是否开放自动执行        |
|:-------- |:----------------------------------------- |:------------------ |:--------------- |
| 一级（极低风险） | 清理7天前的日志文件、清理/tmp临时文件、释放系统缓存、清理Docker无用镜像 | Agent全自动执行，无需人工确认  | ✅ 二期开放          |
| 二级（中风险）  | 重启非核心应用服务、重载Nginx配置、扩容应用线程数               | 生成确认卡片，运维钉钉点击确认后执行 | ⚠️ 二期可选，建议先影子模式 |
| 三级（高风险）  | 重启数据库、杀进程、修改系统配置、删除业务数据                   | 绝对禁止自动执行，只给操作步骤    | ❌ 二期绝对不开放       |

#### 具体落地步骤

1. **封装自愈工具接口（2天）**
   - 在一期的FastAPI接口项目中，新增2-3个一级风险的执行接口
   - 示例：日志清理接口
     - 入参：服务器IP、日志路径、保留天数
     - 执行逻辑：仅删除指定路径下N天前的.log文件，执行前备份操作记录
     - 返回：执行结果、删除文件数量、释放空间大小
   - 强制要求：所有执行接口必须包含**审计日志、操作白名单、执行超时**三个机制
2. **接入Dify工具（0.5天）**
   - 在主排障Agent的工具列表中，新增自愈工具
   - 工具描述明确约束：仅在确认根因属于日志占满、缓存过高等对应场景时调用
3. **提示词加固护栏**
   - 补充规则：自动执行前必须二次确认故障场景匹配，禁止越权调用工具；执行后必须验证执行效果，确认问题解决
   - 所有自动执行操作，必须在输出中明确标注「已自动执行」，并附执行结果

#### 绝对不能碰的风控红线

1. 所有执行接口只能操作白名单内的服务器、白名单内的路径，禁止通配符删除
2. 任何删除类操作，必须先备份到临时目录，保留24小时再清理
3. 增加全局紧急开关：可一键关闭所有自动执行权限，降级为纯建议模式
4. 数据库、核心业务相关的操作，永远不开放自动执行权限

---

### 模块4：结果推送与审计闭环（落地到运维日常工作流）

**解决的问题**：一期需要登录Dify看结果，二期直接把诊断报告、自愈结果推到运维日常用的钉钉/企业微信，同时留存全链路审计日志。

#### 具体实现

1. **钉钉/企业微信告警推送（1天）**
   
   - 新建一个简单的推送接口，或者直接用Dify的工作流节点调用钉钉机器人Webhook
   - 推送内容分级：
     - P1告警：@对应负责人，包含故障概述、根因结论、修复步骤、是否已自动执行
     - P2告警：普通消息，包含诊断报告链接
     - 每日汇总：当日所有告警处理情况统计
   - 二级风险操作：推送「确认执行」卡片，运维点击按钮即可触发执行，不用登录服务器

2. **全链路审计日志（0.5天）**
   
   - 记录每一条告警的完整生命周期：告警时间→预处理结果→工具调用记录→根因结论→执行操作→人工反馈
   - 存储到本地数据库或Excel台账，满足运维审计要求
   - 每日自动生成日报：处理告警数、自动解决数、人工介入数、平均处理时长

3. **人工反馈闭环**
   
   - 推送的报告末尾增加「准确/不准确」反馈按钮
   - 不准确的案例，自动标记进入复盘清单，定期优化提示词和知识库

## 三、二期选做模块（建议放三期，避免范围蔓延）

以下功能价值较高，但二期不建议做，避免精力分散，先把上面4个核心模块跑稳：

1. **多智能体协同**：拆分数据库专家Agent、系统专家Agent、网络专家Agent，复杂故障自动分工协作
2. **CMDB资产对接**：自动拉取服务器角色、服务归属、负责人信息，影响范围判断更精准
3. **全链路拓扑分析**：结合调用链数据，精准定位故障影响的业务范围
4. **自动生成故障复盘报告**：故障解决后，自动生成结构化复盘文档

## 四、二期10天落地时间线

| 时间    | 工作内容                            | 交付物                 |
|:----- |:------------------------------- |:------------------- |
| 第1-2天 | 部署告警预处理Agent，编写转发脚本，对接监控Webhook | 告警自动流入，预处理结果正常输出    |
| 第3-4天 | 整理历史故障案例与SOP，搭建向量知识库，关联主排障Agent | 排障时自动召回历史案例，准确率验证达标 |
| 第5-7天 | 封装低风险自愈工具接口，接入Dify，配置风控规则与审计日志  | 日志占满等简单故障自动执行修复     |
| 第8-9天 | 对接钉钉推送，配置告警分级通知，搭建每日汇总台账        | 告警结果自动触达运维，无需登录Dify |
| 第10天  | 全链路联调测试，影子模式试运行，优化提示词与召回效果      | 全流程跑通，正式切换为生产模式     |

## 五、二期必须遵守的3条风控铁律

1. **权限最小化**：自动执行的账号，只授予最小必要权限，禁止用root账号
2. **可回滚可追溯**：所有自动操作必须有审计日志，有回滚方案，出问题能快速定位、快速恢复
3. **灰度上线**：自动自愈功能先开1台测试服务器验证，再逐步扩大到非核心服务器，核心服务器永远保持人工确认模式

## 六、做完二期之后的三期迭代方向

二期跑稳、验证价值后，三期可以往三个方向深化：

1. **深度自愈**：逐步开放二级风险操作，扩大自动解决故障范围
2. **智能巡检**：新增定时巡检Agent，主动发现潜在风险，提前预警，而不是等故障发生再处理
3. **多智能体团队**：拆分专业领域子Agent，处理复杂故障，对标资深运维团队能力

## 一、低风险自愈工具 Python 接口实现（基于原有 FastAPI 扩展）

以下代码直接追加到你一期的 `main.py` 文件末尾即可，完全兼容原有架构。所有接口默认开启**试运行模式**，只模拟不真实删除，验证无误后再开启真实执行，全程风险可控。

### 1. 前置风控原则（必须遵守）

- 仅开放**一级极低风险**操作：只清理过期日志、临时文件、Docker无用资源，绝不碰业务数据、核心配置、进程管理
- 双重安全校验：IP白名单 + 路径白名单，防止越权操作与路径遍历攻击
- 默认试运行：所有接口默认 `dry_run=True`，只返回待清理清单，不执行真实删除
- 全程可审计：所有操作记录审计日志，包含调用方、时间、操作内容、执行结果

> 说明：当前为单机本地执行版本，接口服务部署在哪台服务器，就清理哪台的文件；多服务器远程执行建议放三期通过 Ansible/SSH 封装实现，二期先做单机验证灰度。

### 2. 完整扩展代码

先补充依赖：

```bash
pip install requests python-multipart
```

追加到 `main.py` 中的完整代码：

```python
import os
import time
import logging
import urllib.parse
import hashlib
import base64
import hmac
import requests
from fastapi import HTTPException, Header
from typing import Optional

# ========== 自愈工具全局安全配置 ==========
# 允许执行自愈操作的服务器IP白名单（二期先只加测试服务器，逐步扩容）
ALLOWED_SERVER_IPS = ["192.168.1.20", "192.168.1.21"]
# 允许清理的日志路径白名单（禁止使用根目录，必须精确到具体日志目录）
ALLOWED_LOG_PATHS = ["/var/log/nginx/", "/data/app/logs/", "/tmp/"]
# 最小保留天数，防止误删近期日志
MIN_KEEP_DAYS = 3

# 审计日志配置
logging.basicConfig(
    filename="ops_agent_audit.log",
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
audit_logger = logging.getLogger("audit")

# ========== 安全校验工具函数 ==========
def validate_server_ip(ip: str):
    """校验服务器IP是否在白名单内"""
    if ip not in ALLOWED_SERVER_IPS:
        raise HTTPException(status_code=403, detail=f"服务器{ip}不在自愈白名单内，禁止执行操作")

def validate_path(path: str):
    """校验路径合法性，防止路径遍历攻击"""
    if ".." in path or "~" in path:
        raise HTTPException(status_code=403, detail="非法路径，禁止使用路径遍历字符")
    in_whitelist = any(path.startswith(allowed) for allowed in ALLOWED_LOG_PATHS)
    if not in_whitelist:
        raise HTTPException(status_code=403, detail="路径不在白名单范围内，禁止清理")

def get_expired_files(path: str, keep_days: int) -> list:
    """获取指定路径下超过保留天数的文件列表"""
    expired_files = []
    now = time.time()
    cutoff = now - (keep_days * 86400)

    for root, dirs, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                if os.path.getmtime(file_path) < cutoff:
                    file_size = os.path.getsize(file_path) / 1024 / 1024
                    expired_files.append({
                        "file_path": file_path,
                        "size_mb": round(file_size, 2),
                        "modify_time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(os.path.getmtime(file_path)))
                    })
            except Exception:
                continue
    return expired_files

# ========== 核心自愈接口 ==========

# 接口1：清理历史日志文件（最高频使用）
@app.post("/api/ops/self-healing/clean-old-logs")
def clean_old_logs(
    server_ip: str,
    log_path: str,
    keep_days: int = 7,
    dry_run: bool = True,
    x_operator: Optional[str] = Header(default="ops-agent")
):
    """
    清理指定路径下的过期日志文件（一级低风险）
    - server_ip: 目标服务器IP
    - log_path: 日志目录路径
    - keep_days: 保留天数，默认7天，不能小于3天
    - dry_run: 试运行模式，默认True，仅返回待清理清单，不真实删除
    """
    # 安全校验
    validate_server_ip(server_ip)
    validate_path(log_path)
    if keep_days < MIN_KEEP_DAYS:
        raise HTTPException(status_code=400, detail=f"保留天数不能小于{MIN_KEEP_DAYS}天")
    if not os.path.isdir(log_path):
        raise HTTPException(status_code=400, detail="日志路径不存在")

    # 获取过期文件
    expired_files = get_expired_files(log_path, keep_days)
    total_size_mb = round(sum(f["size_mb"] for f in expired_files), 2)

    # 执行删除（非试运行模式）
    deleted_count = 0
    if not dry_run:
        for file in expired_files:
            try:
                os.remove(file["file_path"])
                deleted_count += 1
            except Exception as e:
                audit_logger.warning(f"删除失败: {file['file_path']}, 原因: {str(e)}")

    # 记录审计日志
    audit_logger.info(
        f"操作人:{x_operator} | 操作:清理历史日志 | 服务器:{server_ip} | 路径:{log_path} | "
        f"保留天数:{keep_days} | 试运行:{dry_run} | 待清理文件数:{len(expired_files)} | "
        f"已清理数:{deleted_count} | 释放空间:{total_size_mb}MB"
    )

    return {
        "server_ip": server_ip,
        "log_path": log_path,
        "keep_days": keep_days,
        "dry_run": dry_run,
        "expired_file_count": len(expired_files),
        "total_release_mb": total_size_mb,
        "deleted_count": deleted_count,
        "expired_files_preview": expired_files[:10]
    }

# 接口2：清理系统临时文件 /tmp 目录
@app.post("/api/ops/self-healing/clean-tmp")
def clean_tmp_files(
    server_ip: str,
    keep_hours: int = 24,
    dry_run: bool = True,
    x_operator: Optional[str] = Header(default="ops-agent")
):
    """清理系统/tmp目录下超过指定时长的临时文件（一级低风险）"""
    validate_server_ip(server_ip)
    tmp_path = "/tmp/"

    now = time.time()
    cutoff = now - (keep_hours * 3600)
    expired_files = []

    for file in os.listdir(tmp_path):
        file_path = os.path.join(tmp_path, file)
        if os.path.isfile(file_path):
            try:
                if os.path.getmtime(file_path) < cutoff:
                    size = round(os.path.getsize(file_path)/1024/1024, 2)
                    expired_files.append({"file_name": file, "size_mb": size})
            except Exception:
                continue

    total_size = round(sum(f["size_mb"] for f in expired_files), 2)
    deleted_count = 0

    if not dry_run:
        for f in expired_files:
            try:
                os.remove(os.path.join(tmp_path, f["file_name"]))
                deleted_count += 1
            except Exception:
                pass

    audit_logger.info(
        f"操作人:{x_operator} | 操作:清理临时文件 | 服务器:{server_ip} | "
        f"保留时长:{keep_hours}小时 | 试运行:{dry_run} | 释放空间:{total_size}MB"
    )

    return {
        "server_ip": server_ip,
        "tmp_path": tmp_path,
        "keep_hours": keep_hours,
        "dry_run": dry_run,
        "expired_count": len(expired_files),
        "deleted_count": deleted_count,
        "total_release_mb": total_size
    }
```

### 3. 测试与上线步骤

1. **试运行测试**：调用接口时保持 `dry_run=True`，查看返回的待清理文件清单是否正确，无真实删除操作
2. **测试机验证**：将一台非核心测试服务器加入IP白名单，传 `dry_run=False` 执行，核对删除结果与审计日志
3. **生产灰度上线**：先加入1-2台非核心生产服务器，观察3天无异常后逐步扩容，核心业务服务器永不加入自动执行白名单

### 4. 安全加固要点

- 禁止使用 root 账号运行接口服务，使用低权限专用账号
- 接口仅在内网访问，禁止暴露公网，建议增加 API Key 鉴权
- 每周核对一次自愈操作审计日志，确保无异常操作
- 所有删除类操作，预留24小时备份回滚期（可扩展为删除前先移动到备份目录）

---

## 二、钉钉告警推送完整落地配置

实现效果：告警预处理结果、排障诊断报告、自愈执行结果自动推送到运维群，P1级故障自动@负责人，无需登录 Dify 就能获取完整信息。

### 1. 第一步：钉钉侧创建自定义机器人

1. 打开钉钉运维群 → 右上角【群设置】→【机器人】→【添加机器人】
2. 选择【自定义】机器人，命名为「运维智能体」，添加到对应群
3. **安全设置**（二选一，推荐加签模式）：
   - 加签模式：勾选【加签】，复制加签密钥（代码中需要使用）
   - 关键词模式：勾选【自定义关键词】，添加「运维告警」「故障诊断」等关键词，消息必须包含关键词才能发送
4. 创建完成后，复制 Webhook 地址，妥善保存。

### 2. 第二步：封装推送接口（整合进现有 FastAPI）

继续追加到 `main.py` 中，支持 Markdown 格式、分级告警、自动@人：

```python
# ========== 钉钉推送配置 ==========
DINGTALK_WEBHOOK = "https://oapi.dingtalk.com/robot/send?access_token=你的WebhookToken"
DINGTALK_SECRET = "你的加签密钥"  # 使用关键词模式则留空
# P1告警自动@的负责人手机号
AT_MOBILES = ["138xxxxxxxxx", "139xxxxxxxxx"]

def generate_dingtalk_sign():
    """生成钉钉加签签名"""
    timestamp = str(round(time.time() * 1000))
    secret_enc = DINGTALK_SECRET.encode('utf-8')
    string_to_sign = f"{timestamp}\n{DINGTALK_SECRET}"
    string_to_sign_enc = string_to_sign.encode('utf-8')
    hmac_code = hmac.new(secret_enc, string_to_sign_enc, digestmod=hashlib.sha256).digest()
    sign = urllib.parse.quote_plus(base64.b64encode(hmac_code))
    return timestamp, sign

def send_dingtalk_msg(title: str, content: str, level: str = "P2", at_all: bool = False):
    """发送钉钉Markdown格式告警消息"""
    webhook_url = DINGTALK_WEBHOOK
    if DINGTALK_SECRET:
        timestamp, sign = generate_dingtalk_sign()
        webhook_url = f"{webhook_url}&timestamp={timestamp}&sign={sign}"

    # 等级颜色标记
    level_color = {"P1": "#FF0000", "P2": "#FFA500", "P3": "#008000"}
    color = level_color.get(level, "#000000")

    markdown_text = f"""## <font color={color}>[{level}] {title}</font>
{content}
---
**来源**：运维自愈智能体
**时间**：{time.strftime("%Y-%m-%d %H:%M:%S")}
"""

    body = {
        "msgtype": "markdown",
        "markdown": {
            "title": f"[{level}] {title}",
            "text": markdown_text
        },
        "at": {
            "atMobiles": AT_MOBILES if level == "P1" else [],
            "isAtAll": at_all
        }
    }

    try:
        resp = requests.post(webhook_url, json=body, timeout=5)
        return {"status": "success", "response": resp.json()}
    except Exception as e:
        return {"status": "failed", "error": str(e)}

# 对外暴露的推送接口（供Dify调用）
@app.post("/api/ops/notify/dingtalk")
def dingtalk_notify(title: str, content: str, level: str = "P2"):
    """钉钉告警推送接口"""
    result = send_dingtalk_msg(title, content, level)
    return result
```

### 3. 第三步：Dify 侧配置（推荐工具调用方式）

将推送能力封装为工具，让主排障Agent完成诊断后自动推送，和推理逻辑无缝衔接。

1. 进入主排障Agent → 工具管理 → 新建自定义HTTP工具
   - 工具标识：`send_dingtalk_notify`
   - 工具名称：钉钉告警推送
   - 工具描述：故障诊断完成后，调用此工具将根因结论、修复方案、执行结果推送到钉钉运维群
   - 请求方式：POST
   - 接口URL：`http://宿主机内网IP:8001/api/ops/notify/dingtalk`
   - 必填参数：`title`（消息标题）、`content`（消息正文）；选填参数：`level`（告警等级，默认P2）
2. 在系统提示词中补充规则：
   
   > 完成故障诊断、输出最终结论后，必须调用「钉钉告警推送」工具，将完整诊断报告推送到运维群；P1级故障必须标注等级，自动@负责人。

### 4. 标准消息模板（直接写入提示词）

约定统一的推送格式，保证消息清晰易读：

```
### 故障概述
数据库慢查询引发核心交易链路接口超时
### 根因结论
MySQL主库存在无索引慢SQL，导致CPU飙升至96%，下游接口响应超时
### 关键证据
1. 慢SQL峰值260条/分钟，单条最长执行6.2秒
2. mysqld进程占用CPU 87.1%
### 修复建议
1. 为goods表name字段添加普通索引
2. 建议业务低峰期灰度执行
### 处理状态
已生成修复方案，待人工确认执行
```

---

## 三、二期功能验收测试用例

1. **自愈接口验收**：调用日志清理接口，试运行模式下仅返回清单无删除；真实执行模式下正确删除过期文件，审计日志完整记录
2. **钉钉推送验收**：调用推送接口，运维群正常收到带格式的告警消息，P1级自动@对应负责人
3. **全链路验收**：输入一条磁盘占满告警，Agent自主诊断为日志过期占用 → 自动调用自愈工具清理 → 执行完成后自动推送结果到钉钉
   
   
   
   


