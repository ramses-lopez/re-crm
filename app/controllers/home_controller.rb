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

      sp = open_spreadsheet(file)

      sp.default_sheet = sp.sheets.first

      0.upto(sp.last_row) do |line|

        event = sp.cell(line, 'A')
        date = sp.cell(line, 'B')
        name = sp.cell(line, 'C')
        mobile_phone = sp.cell(line, 'D')
        office_phone = sp.cell(line, 'E')
        home_phone = sp.cell(line, 'F')
        address = sp.cell(line, 'G')
        e_mail1 = sp.cell(line, 'H')
        e_mail2 = sp.cell(line, 'I')
        website = sp.cell(line, 'J')
        company = sp.cell(line, 'K')
        city = sp.cell(line, 'L')
        country = sp.cell(line, 'M')
        property_type = sp.cell(line, 'N')
        property_location = sp.cell(line, 'O')
        amount = sp.cell(line, 'P')
        services = sp.cell(line, 'Q')
        referred_by = sp.cell(line, 'R')

        unless name.nil? || name.blank?

          name = name_filter(name)

          c = Contact.new
          c.event = event
          c.first_name = name[0]
          c.last_name = name[1]
          c.email = e_mail1.nil? ? '' : e_mail1.gsub(/\s+/, " ").strip[0,64]
          c.alt_email = e_mail2.nil? ? '' : e_mail2.gsub(/\s+/, " ").strip[0,64]
          c.property_type = property_type
          c.property_location = property_location
          c.services = services

          unless mobile_phone.nil?
            c.phone = mobile_phone.to_s.gsub(/\s+/, " ").strip[0,32]
          end

          c.save
        end

      end

      msg = "Upload successful"
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

  def name_filter(name)

    first, last = ''

    name.strip!

    if name.include? ','
      i = name.index(',')
      last = name[0, i]
      first = name[i+1, name.size]
    else
      i = name.index(' ')

      unless i.nil?
        first = name[0, i]
        last = name[i, name.size]
      else
        first = name
      end
    end

    first.strip! unless first.nil?
    last.strip! unless last.nil?

    return first, last

  end

  def open_spreadsheet(file)
    case File.extname(file.original_filename)
      #when '.csv' then Csv.new(file.path, nil, :ignore)
      when '.xls' then Roo::Excel.new(file.path, nil, :ignore)
      when '.xlsx' then Roo::Excelx.new(file.path, nil, :ignore)
      when '.ods' then Roo::OpenOffice.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end


end
