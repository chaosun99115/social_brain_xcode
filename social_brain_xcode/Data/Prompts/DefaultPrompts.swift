import Foundation

/// Default prompts that will be ingested when the app is first installed
enum DefaultPrompts {
    /// Returns an array of default prompts to be ingested
    static let prompts: [(identifier: Int, name: String, intro: String, display: String, content: String, type: Int16)] = [
        (
            // 0*: sample mode, 1: regular mode
            identifier: 01,
            name: "回顾社交话题",
            intro: "intro1j简介内容",
            display: "职场社交技巧指南",
            content: """
            在职场中建立和维护良好的人际关系是职业发展的重要一环。以下是一些实用的职场社交技巧：

            1. 主动建立联系
            - 参加公司活动
            - 参与跨部门项目
            - 主动与同事共进午餐

            2. 有效沟通
            - 倾听比说话更重要
            - 保持专业但友好的语气
            - 及时回应邮件和消息

            3. 建立信任
            - 遵守承诺
            - 保持诚实透明
            - 尊重他人隐私

            4. 处理冲突
            - 保持冷静客观
            - 寻求双赢解决方案
            - 必要时寻求上级帮助

            5. 维护关系
            - 定期保持联系
            - 分享有价值的信息
            - 在他人需要时提供帮助
            """,
            // 0: hidden, 1: open
            type: 0
        ),
        (
            identifier: 02,
            name: "联络",
            intro: "intro2简介内容",
            display: "社交场合话题指南",
            content: """
            在不同社交场合中，合适的话题选择可以帮助建立良好的互动氛围：

            1. 初次见面
            - 共同的工作或学习经历
            - 兴趣爱好
            - 最近的热点话题

            2. 商务场合
            - 行业动态
            - 专业经验分享
            - 职业发展规划

            3. 休闲场合
            - 旅行经历
            - 美食推荐
            - 文化活动

            4. 避免的话题
            - 敏感政治话题
            - 个人隐私
            - 争议性话题

            5. 话题转换技巧
            - 自然过渡
            - 寻找共同兴趣
            - 适时引导新话题
            """,
            type: 0
        )
    ]
} 