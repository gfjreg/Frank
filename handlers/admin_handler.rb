#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/role'
require 'models/preference'

class AdminHandler < Frank

  #if logged in and if an admin then list all the users
  get '/users' do
    admin_required! "/"
    # an admin user can list everyone
    user_list = User.all
    haml :'in/list_users', :locals => { :message => t.u.list_users_message(user_list.size),
      :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
  end

  #if logged in and if an admin then you may create a new user.
  get '/user' do
    admin_required! "/"
    haml :'in/new_user', :locals => { :message => t.u.create_user_message,
      :user => active_user, :nav_hint => "new_user" }
  end

  #if logged in and if an admin then you may create a new role.
  get '/role' do
    admin_required! "/"
    haml :'in/new_role', :locals => { :message => t.u.create_role_message,
      :user => active_user, :nav_hint => "new_role" }
  end

  #if logged in and if an admin then you may create a new role.
  post '/role' do
    admin_required! "/"
    new_name = params[:new_name]
    # check the role name doesn't already exist
    if Role.find_by_name(new_name) != nil
      haml :'in/new_role', :locals => { :message => t.u.create_role_error(new_name),
        :user => active_user, :nav_hint => "new_role" }     
    else
      new_role = Role.create( :name => new_name )
      @@log.debug("Created new role with name #{new_role.name}")
      role_list = Role.all
      @@log.debug("There are now #{t.roles(Role.count)}")
      haml :'in/list_roles', :locals => { :message => t.u.create_role_success(new_name),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    end
  end

  #if logged in and if an admin then you may create a new user.
  post '/user' do
    admin_required! "/"
    new_name = params[:username]
    new_email = params[:email]
    new_password = params[:password]
    new_html_pref = params[:html_email]
    new_locale = params[:_locale]

    # check the user name doesn't already exist
    if User.find_by_username(new_name) != nil
      haml :'in/new_user', :locals => { :message => t.u.create_user_username_error(new_name),
        :user => active_user, :nav_hint => "new_user" }     
    elsif User.find_by_email(new_email) != nil
      haml :'in/new_user', :locals => { :message => t.u.create_user_email_error(new_email),
        :user => active_user, :nav_hint => "new_user" }           
    else
      new_user = User.create( :username => new_name, :password => new_password, :email => new_email )
      new_user.set_preference('HTML_EMAIL', new_html_pref)
      new_user.locale = new_locale
      new_user.validated = true # lets not get fancy right now.
      # add the roles
      new_roles = params[:roles]
      if new_roles != nil
        for role in new_roles do
          new_user.add_role(role) unless role == ''
        end
      end
      new_user.save!
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.create_user_success(new_name),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then you may show the user's details.
  get '/user/:id' do
    admin_required! "/"
    # an admin user can display anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      haml :'in/show_user', :locals => { :message => t.u.show_user_message(target_user.username), :user => active_user, :target_user => target_user, :nav_hint => "show_user" }
    end
  end

  # if logged in and if an admin then you may edit the user's details.
  # here we show the edit form.
  get '/user/edit/:id' do
    admin_required! "/"
    # an admin user can edit anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      haml :'in/edit_user', :locals => { :message => t.u.edit_user_message(target_user.username), :user => active_user, :target_user => target_user, :nav_hint => "edit_user" }
    end
  end

  #if logged in and if an admin then edit the user
  post '/user/edit/:id' do
    admin_required! "/"
    # an admin user can edit anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else      
      new_email = params['email']
      new_password = params['password']
      new_html_email_pref = params['html_email']
    
      user_changed = false
      error = false
      message = t.u.edit_user_success
    
      old_html_email_pref = target_user.get_preference('HTML_EMAIL').value

      if old_html_email_pref != new_html_email_pref
        target_user.set_preference('HTML_EMAIL', new_html_email_pref)
        user_changed = true
      end
      # if the password is not '' then overwrite the password with the one supplied
      if new_password != ''
        target_user.password = new_password
        user_changed = true
      end
      # if the email is new then deactivate and send a confirmation message
      if new_email != target_user.email
        if User.email_exists?(new_email)
          # don't bother to notify
          message = "#{t.u.edit_user_error_email_clash(new_email)} #{t.u.edit_user_error}"
          error = true
        else
          target_user.email = new_email
          target_user.validated = true
          user_changed = true
        end
      end
      new_locale = params['_locale']  # note different to when editing one's own profile.
      # just check the locale code provided is legit.
      if target_user.locale != new_locale && locale_available?(new_locale)
        target_user.locale = new_locale
        user_changed = true
      end
      new_roles = params[:roles]
      roles_changed = false
      if new_roles.size != target_user.roles.size + 1 # remember the 'none' option.
        roles_changed = true
      else
        # same number of roles so lets see if they actually match
        for new_role in new_roles do
          roles_changed &&= !target_user.has_role?(new_role)
        end
      end
      if roles_changed
        target_user.replace_roles(new_roles)
        user_changed = true
      end
      if error
        haml :'in/edit_user', :locals => { :message => message, :user => active_user, :target_user => target_user, :nav_hint => "edit_user" }
      elsif user_changed
        target_user.save!
        haml :'in/show_user', :locals => { :message => message, :user => active_user, :target_user => target_user, :nav_hint => "show_user" }
      else
        haml :'in/show_user', :locals => { :message => t.u.edit_user_no_change, :user => active_user, :target_user => target_user, :nav_hint => "profile" }
      end
    end
  end

  #if logged in and if an admin then edit the user
  post '/user/delete/:id' do
    admin_required! "/"
    # an admin user can delete anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    elsif target_user.has_role?('superuser')
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_cant_delete_superuser_message, :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      tu_name = target_user.username
      target_user.destroy
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.delete_user_success_message(tu_name), :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then list all the users
  get '/roles' do
    admin_required! "/"
    # an admin user can list roles
    role_list = Role.all
    haml :'in/list_roles', :locals => { :message => t.u.list_roles_message(role_list.size), :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
  end
  
  get '/role/edit/:name' do
    admin_required! "/"
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    else
      haml :'in/edit_role', :locals => { :message => t.u.edit_role_message(target_role.name), :user => active_user, :target_role => target_role, :nav_hint => "edit_role" }
    end
  end

  post '/role/edit/:name' do
    admin_required! "/"
    new_name = params[:new_name]
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    elsif new_name == target_role.name
      # no changes.
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.edit_role_no_change,
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }            
    elsif Role.find_by_name(new_name) != nil  # there's already a role called #{newname}
      # TODO: for now just call error but a better solution is to offer to merge the roles.
      #       Need to define business logic for that so it's beyond the scope of Frank.
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.error_dupe_role_name_message(new_name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }            
    else
      # change the name of the role.  How does this affect other users in that role? (TODO: test that)
      target_role.name = new_name
      target_role.save!
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.edit_role_success,
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    end
  end

  post '/role/delete/:name' do
    admin_required! "/"
      target_role = Role.find_by_name(params[:name])
      if target_role == nil
        role_list = Role.all
        haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
          :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
      elsif is_blessed_role?(target_role)
        role_list = Role.all
        haml :'in/list_roles', :locals => { :message => t.u.error_cant_delete_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
          :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
      else
        target_role.destroy
        role_list = Role.all
        haml :'in/list_roles', :locals => { :message => t.u.delete_role_message(target_role.name), 
          :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
      end
    end

end
