module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      # 有有效 session 即允许建立连接；current_user 可能为 nil（当前身份在该 account 下无 User，如访问其他账户公开看板）
      def set_current_user
        return unless session = find_session_by_cookie
        account = Account.find_by(id: request.env["buzzy.account_id"])
        Current.account = account
        self.current_user = account ? session.identity.users.find_by(account: account) : nil
        true
      end

      def find_session_by_cookie
        Session.find_signed(cookies.signed[:session_token])
      end
  end
end
