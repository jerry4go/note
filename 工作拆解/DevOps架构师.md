岗位职责:
AI编码助手与CodeRAG系统建设（40%）
构建Repository级代码解引引擎：基于Tree-sitter/ANTLR实现代码解析与索引，构建CodeRAG架构（支持搜索+关键词混合认知），为AI Agent提供精准代码上下文（支持Java/Go/Python多语言）
开发AI代码审查服务：基于AWS Bedrock/自建LLM网关，构建流式Diff分析接口，实现安全风险扫描（秘密泄露、SQL注入）+代码规范自动修复建议
负责LLM网关设计与开发：统一接入多模型（Claude/GPT/自研模型），实现流式输出、Token限流、成本监控与提示版

DevOps Agent与AICD模拟（40%）
构建DevOps智能体（Agent）：基于LangChain/AutoGen开发具备工具调用能力的Agent，打通GitLab CI/SPUG，实现故障自愈（自动回滚、扩容决策）、智能排障（日志分析→根因定位→修复脚本执行）
设计AICD（AI驱动的CI/CD）：将LLM能力融入构建流程（智能测试用例生成、失败日志自动获驻）、发布阶段（变更风险评估、自动灰度策略生成）
基础即代码（IaC）：使用Terraform/Pulumi管理AWS EKS集群、IAM策略、安全组，确保AI服务基础设施符合安全合规

系统安全与AWS云原生运维（20%）
AI系统安全：模型实施推理服务的安全防护（输入过滤防提示注入、输出审计防数据泄露）、供应链安全（模型文件签名验证、依赖漏洞扫描Trivy/Snyk）
AWS成本与可上线性：基于CloudWatch/Prometheus/Grafana构建LLM应用专属监控（Token消耗/延迟/成本看板），实现GPU/Spot实例的智能调度与成本优化（FinOps）

工程要求:
编程语言：精通Go或Java（云端服务开发），熟练使用Python（AI Pipeline胶水代码）
AWS深度经验：3年以上AWS实战经验，必须包含：
EKS集群生产级运维（含Karpenter自动扩缩容、Istio服务网格）
IAM精细权限设计、VPC网络规划、KMS加密管理
AI工程落地经验（二选一即可）：
路径A：开发AI编码工具（如基于AST的代码分析、代码审查自动化、IDE插件插件）
路径B：开发过DevOps Agent（如基于LLM的故障诊断、自动运维脚本生成、ChatOps机器人）
云原生基础：精通K8s（CKA认证优先）、Helm Chart开发、ArgoCD/GitOps工作流程

K8S