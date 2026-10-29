# Renders the users table inside a host <form>, like a tab on an edit page.
# The create action redirects back with the submitted params so tests can
# check that the form submits and what it sends. (Turbo needs a redirect.)
class FormEmbeddedUsersController < ApplicationController
  def index
    @submitted = flash[:submitted]
  end

  def create
    flash[:submitted] = request.request_parameters.except("authenticity_token").to_json
    redirect_to form_embedded_users_path, status: :see_other
  end
end
