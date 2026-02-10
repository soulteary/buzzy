# frozen_string_literal: true

module Admin
  class BoardsController < ApplicationController
    # 锁定/解锁可能在目标看板所在账户的 URL 下请求，当前身份在该账户下可能无 User，需跳过否则会 302 到 session/menu
    skip_before_action :require_user_in_account
    allow_unauthorized_access

    before_action :require_super_admin
    before_action :set_board

    def toggle_visibility_lock
      locked = !@board.visibility_locked?
      attrs = {
        visibility_locked: locked,
        visibility_locked_at: locked ? Time.current : nil,
        visibility_locked_by_id: locked ? Current.user&.id : nil
      }
      if @board.update(attrs)
        redirect_to admin_all_content_path(script_name: admin_redirect_script_name), notice: visibility_lock_notice
      else
        redirect_to admin_all_content_path(script_name: admin_redirect_script_name), alert: @board.errors.full_messages.to_sentence
      end
    end

    def toggle_edit_lock
      locked = !@board.edit_locked?
      attrs = {
        edit_locked: locked,
        edit_locked_at: locked ? Time.current : nil,
        edit_locked_by_id: locked ? Current.user&.id : nil
      }
      if @board.update(attrs)
        redirect_to admin_all_content_path(script_name: admin_redirect_script_name), notice: edit_lock_notice
      else
        redirect_to admin_all_content_path(script_name: admin_redirect_script_name), alert: @board.errors.full_messages.to_sentence
      end
    end

    private

      def set_board
        @board = Board.find(params[:id])
      end

      # 与 Admin::UsersController 一致：重定向到无前缀的 admin/all_content
      def admin_redirect_script_name
        nil
      end

      def visibility_lock_notice
        if @board.visibility_locked?
          I18n.t("admin.boards.visibility_locked")
        else
          I18n.t("admin.boards.visibility_unlocked")
        end
      end

      def edit_lock_notice
        if @board.edit_locked?
          I18n.t("admin.boards.edit_locked")
        else
          I18n.t("admin.boards.edit_unlocked")
        end
      end
  end
end
