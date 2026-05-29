# 全流程 Review 路线模板

数据中心阶段的 review 路线必须从 HIS 进入开始，不从 ODS 中段开始。

```text
HIS HTTP 接口
  ① 拉取入口和接口请求
HIS Adapter
  ② ClinicalDataEvent 生成和发布
RabbitMQ
  ③ exchange / routing key / queue / listener
ODS Consumer
  ④ ODS raw 表
ETL Dispatcher
  ⑤ 阶段顺序
Clinical Processor
  ⑥ 医院 Extractor
ClinicalDwdWriter
  ⑦ DWD 临床事实
ADS Build
  ⑧ DWD 汇总查询
dc_ads
  ⑨ 全息视图
  ⑩ 全息 chunk
  ⑪ 报告 chunk 向量
Query API
  ⑫ 全息查询 / 向量检索
  ⑬ 来源追溯
```

每一站至少写：

- 重点文件；
- 检查 SQL 或 HTTP endpoint；
- 重点问题；
- 通过标准。
