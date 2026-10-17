# The groups that field the teams of a season, which are called clubs in the
# interface as most groups are a single club. Everybody can see them, admins
# register them before the teams themselves.
class GroupsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_group, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create edit update destroy]
  before_action :require_season!, only: %i[new create]
  before_action :require_editable_season!, only: %i[new create edit update destroy]
  before_action :require_draft_season!, only: %i[new create destroy]

  def index
    @groups = @season ? @season.groups.includes(:clubs, :teams).ordered : Group.none
  end

  def show
    @clubs = @group.clubs.ordered
    @venues = @group.venues.distinct.ordered
    @teams = @group.teams.includes(:league, team_members: :participant).ordered
    @matches = Match.where(home_team: @teams).or(Match.where(away_team: @teams))
      .includes(:venue, :home_team, :away_team, :games, league: :season).scheduled
    @participants = @group.season.participants.joins(:team_member).where(team_members: { team_id: @teams.select(:id) })
      .includes(:club, :home_games, :away_games, team_member: :team).by_rating
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
