# Admins register the groups that field the teams of a season before the teams
# themselves. In the interface they are called clubs, as most groups are a
# single club.
class GroupsController < ApplicationController
  before_action :require_admin!
  before_action :set_group, only: %i[edit update destroy]
  before_action :require_season!, only: %i[index new create]
  before_action :require_editable_season!, only: %i[new create edit update destroy]
  before_action :require_draft_season!, only: %i[new create destroy]

  def index
    @groups = @season.groups.includes(:clubs, :teams).ordered
  end

  def new
    @group = @season.groups.build
  end

  def edit
  end

  def create
    @group = @season.groups.build(group_params)

    if @group.save
      redirect_to groups_url(season_slug: @season.slug), notice: "Club is aangemeld."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @group.update(group_params)
      redirect_to groups_url(season_slug: @season.slug), notice: "Club is bijgewerkt."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @group.destroy
      redirect_to groups_url(season_slug: @season.slug), notice: "Club is afgemeld.", status: :see_other
    else
      flash.now[:alert] = @group.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_group
      @group = Group.find(params[:id])
      set_current_season_from(@group)
    end

    def group_params
      params.expect(group: [:name, club_ids: []])
    end
end
