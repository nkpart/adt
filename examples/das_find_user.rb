# In the destroyallsoftware.com screencast 'Extracting from Controller to Model', Gary goes
# through the motions of extracting a function that can return an object, or raise 2 different
# exceptions. This is well suited to an ADT.

# BEFORE
#
class AccountController
  
  def generate_token
    return unless request.post?
    begin
      user = User.find_user_who_is_allowed_to_reset_password!(params[:mail])
    rescue ActiveRecord::RecordNotFound
      flash.now[:error] = l(:notice_account_unknown_email)
    rescue User::NotAllowedToResetPassword
      flash.now[:error] = l(:notice_can_t_change_password)
    else
      create_new_token(user)
    end
  end

end

# AFTER

class UserReset
  extend ADT
  cases do
    found(:user)
    not_found
    not_allowed
  end

  def self.from_mail mail
    # returns found(user), not_found or not_allowed. Would be similar to the custom find that throws exceptions.
  end
end

class AccountController
  def generate_token
    return unless request.post?
    v = UserReset.from_mail(params[:mail])
    v.fold(
      found: proc { |user| create_new_token(user) },
      not_found: proc { flash.now[:error] = l(:notice_account_unknown_email) },
      not_allowed: proc { flash.now[:error] = l(:notice_can_t_change_password) }
    )
  end
end
