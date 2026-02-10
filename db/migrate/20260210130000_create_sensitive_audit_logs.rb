# frozen_string_literal: true

class CreateSensitiveAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :sensitive_audit_logs, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, index: true
      t.references :user, type: :uuid, null: true, index: true

      t.string :action, null: false
      t.references :subject, type: :uuid, polymorphic: true, null: true, index: true
      t.json :metadata

      t.string :ip_address
      t.datetime :created_at, null: false
    end

    add_index :sensitive_audit_logs, [:account_id, :created_at]
    add_index :sensitive_audit_logs, [:action, :created_at]
  end
end
