extends RefCounted

# true：解锁全部关卡并显示关卡切换箭头；false：正常通关模式。
static var DEV_MODE: bool = true

# 版本开关，与 DEV_MODE 的调试功能独立；Demo 的关卡选择仅显示第一章。
# true：Demo 版；false：开发版。
static var DEMO_MODE: bool = false

# true：网页版；false：桌面版。暂未接入设置或退出按钮的差异。
static var WEB_MODE: bool = false
