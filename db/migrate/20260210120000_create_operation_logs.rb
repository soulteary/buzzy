# frozen_string_literal: true
# 操作流水表：记录 Card/Board/Comment/Column/Tag/Step 等 create/update/destroy。
# 执行后请运行 bin/rails db:migrate（及 db:test:prepare）以更新 schema。
class CreateOperationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :operation_logs, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, index: true
      t.references :board, type: :uuid, null: true, index: true
      t.references :user, type: :uuid, null: true, index: true

      t.string :action, null: false
      t.references :subject, type: :uuid, polymorphic: true, null: true, index: true
      t.json :changes

      t.string :request_id
      t.string :ip_address

      t.datetime :created_at, null: false
    end

    add_index :operation_logs, [:account_id, :created_at]
    add_index :operation_logs, [:board_id, :created_at]
  end
end
