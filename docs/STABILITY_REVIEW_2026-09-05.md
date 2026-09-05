# 本地稳定性审查 — 2026-09-05

审查基线：已发布的 `v0.4.11`（`5b74a336`）。本次为本地修复，不改版本号、不发布、不替换已安装应用。

## 范围与结论

重点检查截图协调器、选区与标注生命周期、导出、全局快捷键、权限恢复、长图采集与拼接的异步边界。保留原生 AppKit / SwiftUI / ScreenCaptureKit 架构，不做无证据的大规模重写。

发现并用回归测试复现了四项缺陷。修复后完整本地验证通过；这不是“所有功能和所有机器均已验收”的结论。

| 优先级 | 已确认问题 | 根因与修复 |
| --- | --- | --- |
| P1 | 取消导出后仍可能保存或改写剪贴板 | detached worker 不继承调用者的取消；加入取消传播、处理后及写入前检查，并在主线程复制前再次检查。 |
| P1 | 同秒并发导出可能互相覆盖 | 两个任务在文件落盘前选择了同一个空闲文件名；共享导出器在等待后台处理前预留路径，结束后释放。 |
| P2 | 修改快捷键时注册旧值，重置后残留绑定 | Combine 订阅在 `@Published` 的 willSet 阶段重新读取属性；将通知送到主队列后读取已更新的设置。 |
| P1 | 长图主线程忙时全分辨率帧无界积压 | 原有 10 帧分析队列限制发生在主线程接收之后，无法限制之前的 Task；图像转换前获取最多 2 个投递名额，实际接收后释放，转换失败也释放。 |

## 回归证据

测试使用合成图像、独立偏好设置和临时文件夹；导出测试注入剪贴板回调，不改写用户剪贴板。

- `ImageExporterTests.testCancellationDuringProcessingDoesNotWriteFileOrClipboard`：阻塞后台处理，取消调用者再放行。修复前失败，修复后抛出取消错误且没有文件、剪贴板写入。
- `ImageExporterTests.testConcurrentExportsDoNotOverwriteOneAnother`：固定时间，同时阻塞两个导出，确认均选定目的地后放行。修复前 URL 相同，修复后生成两个不同文件。
- `ShortcutObservationTests.testRegistrationReadsNewValueAndResetClearsLastShortcut`：走实际订阅逻辑，修改最后一个可选快捷键并重置。修复前读到旧值，修复后读到新值且重置为空。
- `FrameDeliveryTests.testStalledConsumerBoundsFramesBeforeImageConversion`：阻塞消费者，连续提交 200 帧。原投递逻辑转换全部 200 帧；修复后只转换 2 帧，其余在分配图像前跳过。
- `FrameDeliveryTests.testFailedConversionDoesNotExhaustDeliverySlots`：连续模拟 20 次转换失败，名额不会泄漏。

## 完整验证

执行：`DERIVED_DATA_PATH="$PWD/build/Review" ./scripts/ci.sh`，退出码 0。

- 83 项单元及回归测试全部通过（新增 5 项）。
- Release 静态分析通过。
- arm64 / x86_64 通用构建通过；Intel 仅编译验证，未在 Intel 硬件运行。
- Debug / Release 身份隔离、隐私清单、配置及 shell 语法检查通过。
- DMG 创建、镜像校验、ZIP 打包及两份 SHA-256 校验通过。
- 无源码编译诊断；Xcode 的 AppIntents 元数据提取提示为应用未依赖该框架，不是分析失败。

本机临时验证日志：`/tmp/screencapture-stability-ci.log`。
本机测试结果：`build/Review/Logs/Test/Test-ScreenCapture-2026.09.05_10-52-44-+0800.xcresult`。
这些日志和构建产物不提交仓库，打包烟测产物不是签名发行包。

## 边界与后续验收

- 取消是协作式的：正在执行的图像特效或系统文件写入不能被强制中断；已完成的文件不会因随后取消而被删除。测试覆盖取消发生在处理阶段，不宣称事务性回滚。
- 自动文件名预留解决共享导出器内部的并发；不保证其他进程同时创建同名文件时的互斥。用户主动“另存为”的覆盖确认逻辑保持不变。
- 帧投递限制保护内存，但负载过高时会跳帧，不能保证任意快速滚动均能拼接。没有重采样或压缩原始像素；主线程长时间阻塞、动态页面及缺失重叠仍需真机验证。
- 未做新一轮人工 GUI 全流程、真实 TCC 授权撤销/重新授权、外接混合缩放显示器热插拔、睡眠唤醒、macOS 14/15 硬件验收或长时间内存压力测试。
- 长图最终渲染仍使用 detached worker，取消后结果会被丢弃，但已开始的渲染计算可能继续到结束；本轮没有把“取消立即释放全部资源”作为已修复能力。
- 本轮没有签名、公证、安装或推送。后续发行应先完成上述相关真机交互验收，再按发行清单打包。
