class Account::Seeder
  attr_reader :account, :creator

  def initialize(account, creator)
    @account = account
    @creator = creator
  end

  def seed
    Current.set(user: creator, account: account) do
      populate
    end
  end

  def seed!
    raise "You can't run in production environments" unless Rails.env.local?

    delete_everything
    seed
  end

  private
    def populate
      # ---------------
      # 演练场看板（仅创建者可见）
      # ---------------
      playground = account.boards.create! name: "演练场", creator: creator, all_access: false
      playground.update! auto_postpone_period: 365.days

      # 教程卡片
      playground.cards.create! creator: creator, title: "最后，观看这段 Buzzy 入门视频", status: "published", description: <<~MARKDOWN
        Buzzy(Fizzy) 里还能做很多事。下面这段视频中，37signals 创始人兼 CEO Jason Fried 会用大约 17 分钟带你过一遍基础用法。

        Buzzy(Fizzy) 入门：<a href="https://bilibili.com/video/BV1ZncczDE6S/" target="_blank">https://bilibili.com/video/BV1ZncczDE6S/</a>
      MARKDOWN

      playground.cards.create! creator: creator, title: "打开 Buzzy 菜单探索更多", status: "published", description: <<~MARKDOWN
        点击屏幕顶部的「**Buzzy**」或按「J」键打开菜单，可跳转到看板、标签、个人资料等。

        [打开 Buzzy 菜单（视频）](/video/invite-link.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "然后，回到首页查看动态", status: "published", description: <<~MARKDOWN
        按「1」或打开 Buzzy 菜单并选择「首页」。

        [返回首页查看最新动态（视频）](/video/back-to-home.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "现在，查看分配给你的所有卡片", status: "published", description: <<~MARKDOWN
        打开屏幕顶部的 Buzzy 菜单，选择「**分配给我**」，或随时按键盘「2」。

        [查看分配给我的所有卡片（视频）](/video/all-assigned.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "然后，打开 Buzzy 菜单", status: "published", description: <<~MARKDOWN
        Buzzy 菜单是你在应用内导航的方式。点击屏幕顶部的「**Buzzy**」或按键盘「J」键即可打开。

        [打开 Buzzy 菜单（视频）](/video/open-menu.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "接下来，把这张卡片分配给自己", status: "published", description: <<~MARKDOWN
        点击头像旁带 + 的小图标，然后选择自己。

        [把这张卡片分配给自己（视频）](/video/assign-to-self.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "现在，给这张卡片打上「设计」标签并移到「是」列", status: "published", description: <<~MARKDOWN
        点击标签图标，输入「设计」，然后选择「**创建标签**」。再把卡片拖到上一步新建的「是」列。

        [给这张卡片打上 #设计 标签（视频）](/video/tag-design.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "接下来，再创建两列", status: "published", description: <<~MARKDOWN
        1. 一列命名为「是」
        2. 另一列命名为「进行中」

        回到看板视图，在「完成」列右侧点击「+」，命名列、选颜色，再重复一次创建第二列。

        完成后，把这张卡片拖到「完成」列，或在侧边栏选择「完成」。

        [再创建两列（视频）](/video/make-columns.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "第二步，把这张卡片移到「暂不处理」", status: "published", description: <<~MARKDOWN
        可以在侧边栏选择「暂不处理」，或回到看板视图，把这张卡片拖到左侧的「暂不处理」列。

        [移到暂不处理（视频）](/video/not-now.mp4)
      MARKDOWN

      playground.cards.create! creator: creator, title: "第一步，重命名这张卡片", status: "published", description: <<~MARKDOWN
        1. 点击标题即可重命名卡片、修改描述或补充更多信息。
        2. 然后点击卡片底部的「标记为完成」。
        3. 最后点击屏幕左上角的「**返回演练场**」回到看板。

        [重命名这张卡片（视频）](/video/rename.mp4)
      MARKDOWN
    end

    def delete_everything
      Current.set(user: creator, account: account) do
        account.boards.destroy_all
      end
    end
end
