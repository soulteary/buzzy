# frozen_string_literal: true

class AddAdminActionAuditToUsersAndBoards < ActiveRecord::Migration[8.0]
  def change
    # 用户：记录冻结操作的管理员与时间
    add_column :users, :frozen_at, :datetime
    add_column :users, :frozen_by_id, :uuid
    add_index :users, :frozen_by_id

    # 看板：记录锁定可见性/可编辑性的管理员与时间
    add_column :boards, :visibility_locked_at, :datetime
    add_column :boards, :visibility_locked_by_id, :uuid
    add_column :boards, :edit_locked_at, :datetime
    add_column :boards, :edit_locked_by_id, :uuid
    add_index :boards, :visibility_locked_by_id
    add_index :boards, :edit_locked_by_id
  end
end
