class PeopleController < ApplicationController
  before_action :set_person, only: %i[ show edit update destroy ]

  def index
    @people = Person.includes(:club).ordered
  end

  def show
  end

  def new
    @person = Person.new
  end

  def edit
  end

  def create
    @person = Person.new(person_params)

    if @person.save
      redirect_to @person, notice: "Persoon is toegevoegd."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Persoon is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @person.destroy!
    redirect_to people_url, notice: "Persoon is verwijderd.", status: :see_other
  end

  private
    def set_person
      @person = Person.find(params[:id])
    end

    def person_params
      params.expect(person: [ :firstname, :lastname, :egd_pin, :club_id, :email, :email2, :phone, :phone2 ])
    end
end
