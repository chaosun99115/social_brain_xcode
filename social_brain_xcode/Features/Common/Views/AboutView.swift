import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(LocalizedStringKey("""
                社交大脑是你处理复杂人际事务的高效助手，让你在复杂的人际关系里游刃有余。

                **核心功能说明**：

                - **怎样记录人际关系**

                社交大脑可以帮助你记录人际关系里的方方面面：

                1 "关系"页面可以记录人际关系里的"熟人"和"圈子"

                2 "笔记"页面可以分别记录经历过的"人际互动"和收集的"人际话题"。

                清晰的结构可以帮助你快速找到所需的对应信息。

                - **怎样使用关系备忘录**

                1 创建熟人：点击应用底部的 "关系" 图标，创建新的熟人，录入各种基本信息。

                2 创建笔记：点击应用底部的 "笔记" 图标，记录人际互动，并关联对应熟人。

                3 生成备忘录：当你积累了一定数量的互动记录后，在熟人页面的底部点击 "关系备忘录" 按钮，应用将自动生成人际档案库，涵盖你们的过往互动和共同话题。

                - **怎样构建互动话题库**

                1 回顾话题：点击底部的 "社交大脑" 图标，再点击 "回顾一下最近聊过的话题"，应用将罗列值得你回顾的话题列表。

                2 收集话题：点击底部的 "收集话题"入口，随时收集新话题。 "笔记" 页面的 "人际话题" 可以查看和管理所有话题。

                - **怎样获得人际事务提醒**

                联络提醒：点击底部的 "社交大脑" 图标，再点击 "最近有哪些适合联络的朋友"，应用将为你推荐适合近期联络的新朋友和老朋友。

                - **怎样查看示例数据**

                人际大脑提供了两套内置的示例数据，分别对应了使用社交大脑建立人际关系（跳槽新公司）和拓展人际关系（经营自己的独立项目）的两个典型场景。你可以随时切换到示例数据，在具体的场景下体验社交大脑用法。

                - **怎样建立专属人际事务经验库**

                1 进入入口：点击右上角的设置按钮，找到 "人际经验库" 选项并进入。

                2 新建经验：把你自己的经历或想法变成一段可以重复使用的经验，保证你得到的建议或回答都会按照参照你经验里的思路和要求。
                """))
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .padding()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Previews

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .environment(\.colorScheme, .light)
        
        AboutView()
            .environment(\.colorScheme, .dark)
    }
} 