# app/controllers/events_controller.rb
class EventsController < ApplicationController
  before_action :set_event, only: %i(show edit update destroy register presents user_present_new)
  before_action :authenticate_user!, except: %i(index show)

  load_and_authorize_resource except: %i(index show)

  # GET /events
  # GET /events.json
  def index
    @events = Event.all.order('start_at DESC')
  end

  # GET /events
  # GET /events.json
  def index_admin
    @events = Event.all.order('start_at ASC')
  end

  # GET /events/1
  # GET /events/1.json
  def show
  end

  # GET /events/new
  def new
    @event = Event.new
    @event.partners.build
  end

  # GET /events/1/edit
  def edit
  end

  # POST /events
  # POST /events.json
  def create
    @event = Event.new(event_params)

    respond_to do |format|
      if @event.save
        format.html {redirect_to @event, notice: 'Evento foi criado com sucesso!'}
        format.json {render action: 'show', status: :created, location: @event}
      else
        format.html {render action: 'new'}
        format.json {render json: @event.errors, status: :unprocessable_entity}
      end
    end
  end

  # PATCH/PUT /events/1
  # PATCH/PUT /events/1.json
  def update
    respond_to do |format|
      if @event.update(event_params)
        format.html {redirect_to @event, notice: 'Event was successfully updated.'}
        format.json {head :no_content}
      else
        format.html {render action: 'edit'}
        format.json {render json: @event.errors, status: :unprocessable_entity}
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.json
  def destroy
    @event.destroy
    respond_to do |format|
      format.html {redirect_to events_url}
      format.json {head :no_content}
    end
  end

  def register
    return error_email_already_register if @event.is_registrated?(set_user.id)
    return render json: {exceeded_limit: true} if @event.exceeded_limit?
    return register_user if @user.cpf.present?
    params.merge!(register: {}.merge!(cpf: "")) if params[:register].nil?
    return update_cpf_and_registre if params[:register][:cpf] != ""
    error_necessary_cpf
  end

  def presents
    @presents = @event.registrations.where('presence = true').includes("user").order("presence", "users.email")
  end

  def user_present_new
    if (params[:full_name].present? and !params[:full_name].blank?) and (params[:email].present? and !params[:email].blank?)
      user = User.new
      user.first_name = params[:full_name].split(' ').first
      user.last_name = params[:full_name].split(' ')[1..-1].join(' ')
      user.email = params[:email]
      user.password = rand(10 ** 10)

      if user.save
        user.send_reset_password_instructions
        if @event.to_register(user.id)
          registration = Registration.where(user_id: user.id, event_id: @event.id).first
          registration.presence = true
          if registration.save
            redirect_to event_registrations_path(@event), notice: 'Usuario Cadastrado!'
          else
            redirect_to event_registrations_path(@event), alert: "Nao foi possivel salvar! #{registration.errors.messages} "
          end
        else
          redirect_to event_registrations_path(@event), alert: "Nao foi possivel salvar! #{@event.errors.messages} "
        end
      else
        redirect_to event_registrations_path(@event), alert: "Nao foi possivel salvar! #{user.errors.messages} "
      end
    else
      redirect_to event_registrations_path(@event), alert: 'Informe todos os dados!'
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event
    @event = Event.find(params[:id])
  end

  def set_user
    @user = User.find(params[:user_id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def event_params
    params.require(:event).permit(:name, :status, :event_ribbon, :description, :start_at, :end_at, :local, :participants_limit, :provides_certificate,
                                  partners_attributes: [:id, :name, :link, :order, :site, :event_id, :category, :logo,
                                                        :_destroy],
                                  gifts_attributes: [:id, :name, :photo, :_destroy,
                                                     winners_attributes: [:id, :gift_id, :user_id, :_destroy]],
                                  albums_attributes: [:id, :title, :event_id, :_destroy,
                                                      images_attributes: [:id, :title, :asset, :_destroy]],
                                  attachments_attributes: [:id, :name, :file_type, :type, :origin_type, :situation, :file, :_destroy])
  end

  def register_user
    @event.to_register(set_user.id)
    params[:register] = {}.merge!(need_certificate: "0") if params[:register].nil?
    return update_user_need_certificate if params[:register][:need_certificate] == "1"
    register_success
  end

  def error_email_already_register
    redirect_to events_path, flash: {error: "Este email já está registrado no evento!!"}
  end

  def error_necessary_cpf
    redirect_to event_path(@event), flash: {error: "Cpf necessario!"}
  end

  def register_success
    redirect_to events_path, flash: {success: "Inscrito no Evento com sucesso!"}
  end

  def need_certificate
    redirect_to edit_user_registration_path, flash: {error: "Você foi inscrito no evento com sucesso, porém para ter seu certificado emitido precisa preencher todos os dados de seu perfil!"}
  end

  def update_user_need_certificate
    return need_certificate if @user.update_attributes(need_certificate: params[:register][:need_certificate])
  end

  def update_cpf_and_registre
    return register_success if @user.update_attributes(cpf: params[:register][:cpf]) and @event.to_register(set_user.id)
    redirect_to event_path(@event), flash: {error: @user.errors.full_messages.join(',')}
  end

end
