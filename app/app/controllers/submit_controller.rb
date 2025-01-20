# frozen_string_literal: true

class SubmitController < AuthenticatedController
  def index
    @submit = Submit.new
  end

  def create
    @submit = Submit.new(submit_params)
    if @submit.save
      redirect_to root_path
    else
      render :index
    end
  end

  private

  def submit_params
    params.require(:submit).permit(:name, :email, :phone_number, :message)
  end
end
