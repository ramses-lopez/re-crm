# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class HomeController < ApplicationController
  before_filter :require_user, :except => [ :toggle, :timezone ]
  before_filter :set_current_tab, :only => :index
  before_filter "hook(:home_before_filter, self, :amazing => true)"

  def upload

    unless params[:file].nil?

      file = params[:file]

      oo = Roo::OpenOffice.new(file.path, nil, :ignore)

      oo.default_sheet = oo.sheets.first

      0.upto(oo.last_row) do |line|

        event = oo.cell(line, 'A')
        date = oo.cell(line, 'B')
        name = oo.cell(line, 'C')
        mobile_phone = oo.cell(line, 'D')
        office_phone = oo.cell(line, 'E')
        home_phone = oo.cell(line, 'F')
        address = oo.cell(line, 'G')
        e_mail1 = oo.cell(line, 'H')
        e_mail2 = oo.cell(line, 'I')
        website = oo.cell(line, 'J')
        company = oo.cell(line, 'K')
        city = oo.cell(line, 'L')
        country = oo.cell(line, 'M')
        property_type = oo.cell(line, 'N')
        property_location = oo.cell(line, 'O')
        amount = oo.cell(line, 'P')
        services = oo.cell(line, 'Q')
        referred_by = oo.cell(line, 'R')

        c = Contact.new

        c.event = event
        c.first_name = name
        c.last_name = name
        c.property_type = property_type
        c.property_location = property_location
        c.services = services
        c.phone = mobile_phone

        c.save

      end

      msg = "upload successful"
    else
      msg = 'Select a file!'
    end

    redirect_to root_url, notice: msg
  end

  #----------------------------------------------------------------------------
  def index
    @hello = "Hello world" # The hook below can access controller's instance variables.
    hook(:home_controller, self, :params => "it works!")

    @activities = get_activities
    @my_tasks = Task.visible_on_dashboard(current_user).by_due_at
    @my_opportunities = Opportunity.visible_on_dashboard(current_user).by_closes_on.by_amount
    @my_accounts = Account.visible_on_dashboard(current_user).by_name
    respond_with(@activities)
  end

  # GET /home/options                                                      AJAX
  #----------------------------------------------------------------------------
  def options
    unless params[:cancel].true?
      @asset = current_user.pref[:activity_asset] || "all"
      @action = current_user.pref[:activity_event] || "all_events"
      @user = current_user.pref[:activity_user] || "all_users"
      @duration = current_user.pref[:activity_duration] || "two_days"
      @all_users = User.order("first_name, last_name")
    end
  end

  # POST /home/redraw                                                      AJAX
  #----------------------------------------------------------------------------
  def redraw
    current_user.pref[:activity_asset] = params[:asset] if params[:asset]
    current_user.pref[:activity_event] = params[:event] if params[:event]
    current_user.pref[:activity_user] = params[:user] if params[:user]
    current_user.pref[:activity_duration] = params[:duration] if params[:duration]

    render :index
  end

  # GET /home/toggle                                                       AJAX
  #----------------------------------------------------------------------------
  def toggle
    if session[params[:id].to_sym]
      session.delete(params[:id].to_sym)
    else
      session[params[:id].to_sym] = true
    end
    render :nothing => true
  end

  # GET /home/timeline                                                     AJAX
  #----------------------------------------------------------------------------
  def timeline
    unless params[:type].empty?
      model = params[:type].camelize.constantize
      item = model.find(params[:id])
      item.update_attribute(:state, params[:state])
    else
      comments, emails = params[:id].split("+")
      Comment.update_all("state = '#{params[:state]}'", "id IN (#{comments})") unless comments.blank?
      Email.update_all("state = '#{params[:state]}'", "id IN (#{emails})") unless emails.blank?
    end

    render :nothing => true
  end

  # GET /home/timezone                                                     AJAX
  #----------------------------------------------------------------------------
  def timezone
    #
    # (new Date()).getTimezoneOffset() in JavaScript returns (UTC - localtime) in
    # minutes, while ActiveSupport::TimeZone expects (localtime - UTC) in seconds.
    #
    if params[:offset]
      session[:timezone_offset] = params[:offset].to_i * -60
      ActiveSupport::TimeZone[session[:timezone_offset]]
    end
    render :nothing => true
  end

  private
  #----------------------------------------------------------------------------
  def get_activities(options = {})
    options[:asset]    ||= activity_asset
    options[:event]    ||= activity_event
    options[:user]     ||= activity_user
    options[:duration] ||= activity_duration
    options[:max]      ||= 500

    Version.latest(options).visible_to(current_user)
  end

  #----------------------------------------------------------------------------
  def activity_asset
    asset = current_user.pref[:activity_asset]
    if asset.nil? || asset == "all"
      nil
    else
      asset.singularize.capitalize
    end
  end

  #----------------------------------------------------------------------------
  def activity_event
    event = current_user.pref[:activity_event]
    if event == "all_events"
      %w(create update destroy)
    else
      event
    end
  end

  #----------------------------------------------------------------------------
  def activity_user
    user = current_user.pref[:activity_user]
    if user && user != "all_users"
      user = if user =~ /@/ # email
          User.where(:email => user).first
        else # first_name middle_name last_name any_name
          name_query = if user.include?(" ")
            user.name_permutations.map{ |first, last|
              "(upper(first_name) LIKE upper('%#{first}%') AND upper(last_name) LIKE upper('%#{last}%'))"
            }.join(" OR ")
          else
            "upper(first_name) LIKE upper('%#{user}%') OR upper(last_name) LIKE upper('%#{user}%')"
          end
          User.where(name_query).first
        end
    end
    user.is_a?(User) ? user.id : nil
  end

  #----------------------------------------------------------------------------
  def activity_duration
    duration = current_user.pref[:activity_duration]
    if duration
      words = duration.split("_") # "two_weeks" => 2.weeks
      if %w(one two).include?(words.first)
        %w(zero one two).index(words.first).send(words.last)
      end
    end
  end

end
