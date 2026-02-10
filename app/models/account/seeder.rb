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
      playground.cards.create! creator: creator, title: "最后，观看这段 Buzzy 入门视频", status: "published", description: <<~HTML
        <p>Buzzy(Fizzy) 里还能做很多事。下面这段视频中，37signals 创始人兼 CEO Jason Fried 会用大约 17 分钟带你过一遍基础用法。</p>
        <p>Buzzy(Fizzy) 入门：<a href="https://bilibili.com/video/BV1ZncczDE6S/">https://bilibili.com/video/BV1ZncczDE6S/</a></p>
      HTML

      playground.cards.create! creator: creator, title: "打开 Buzzy 菜单探索更多", status: "published", description: <<~HTML
        <p>点击屏幕顶部的「<b><strong>Buzzy</b></strong>」或按「J」键打开菜单，可跳转到看板、标签、个人资料等。</p>
        <action-text-attachment url="/video/invite-link.mp4" caption="打开 Buzzy 菜单" content-type="video/mp4" filename="invite-link.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "然后，回到首页查看动态", status: "published", description: <<~HTML
        <p>按「1」或打开 Buzzy 菜单并选择「首页」。</p>
        <action-text-attachment url="/video/back-to-home.mp4" caption="返回首页查看最新动态" content-type="video/mp4" filename="back-to-home.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "现在，查看分配给你的所有卡片", status: "published", description: <<~HTML
        <p>打开屏幕顶部的 Buzzy 菜单，选择「<b><strong>分配给我</b></strong>」，或随时按键盘「2」。</p>
        <action-text-attachment url="/video/all-assigned.mp4" caption="查看分配给我的所有卡片" content-type="video/mp4" filename="all-assigned.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "然后，打开 Buzzy 菜单", status: "published", description: <<~HTML
        <p>Buzzy 菜单是你在应用内导航的方式。点击屏幕顶部的「<b><strong>Buzzy</b></strong>」或按键盘「J」键即可打开。</p>
        <action-text-attachment url="/video/open-menu.mp4" caption="打开 Buzzy 菜单" content-type="video/mp4" filename="open-menu.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "接下来，把这张卡片分配给自己", status: "published", description: <<~HTML
        <p>点击头像旁带 + 的小图标，然后选择自己。</p>
        <action-text-attachment url="/video/assign-to-self.mp4" caption="把这张卡片分配给自己" content-type="video/mp4" filename="assign-to-self.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "现在，给这张卡片打上「设计」标签并移到「是」列", status: "published", description: <<~HTML
        <p>点击标签图标，输入「设计」，然后选择「<b><strong>创建标签</b></strong>」。再把卡片拖到上一步新建的「是」列。</p>
        <action-text-attachment url="/video/tag-design.mp4" caption="给这张卡片打上 #设计 标签" content-type="video/mp4" filename="tag-design.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "接下来，再创建两列", status: "published", description: <<~HTML
        <ol>
          <li>一列命名为「是」</li>
          <li>另一列命名为「进行中」</li>
        </ol>
        <p>回到看板视图，在「完成」列右侧点击「+」，命名列、选颜色，再重复一次创建第二列。</p>
        <p><br></p>
        <p>完成后，把这张卡片拖到「完成」列，或在侧边栏选择「完成」。</p>
        <action-text-attachment url="/video/make-columns.mp4" caption="再创建两列" content-type="video/mp4" filename="make-columns.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "第二步，把这张卡片移到「暂不处理」", status: "published", description: <<~HTML
        <p>可以在侧边栏选择「暂不处理」，或回到看板视图，把这张卡片拖到左侧的「暂不处理」列。</p>
        <p><br></p>
        <action-text-attachment url="/video/not-now.mp4" caption="移到暂不处理" content-type="video/mp4" filename="not-now.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "第一步，重命名这张卡片", status: "published", description: <<~HTML
        <ol>
          <li>点击标题即可重命名卡片、修改描述或补充更多信息。</li>
          <li>然后点击卡片底部的「标记为完成」。</li>
          <li>最后点击屏幕左上角的「<b><strong>返回演练场</strong></b>」回到看板。</li>
        </ol>
        <action-text-attachment url="/video/rename.mp4" caption="重命名这张卡片" content-type="video/mp4" filename="rename.mp4"></action-text-attachment>
      HTML
    end

    def delete_everything
      Current.set(user: creator, account: account) do
        account.boards.destroy_all
      end
    end
end
