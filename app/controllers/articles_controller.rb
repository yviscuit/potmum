# frozen_string_literal: true
class ArticlesController < ApplicationController
  before_action :set_user!
  before_action :set_article!, only: [:show, :edit, :update, :destroy, :create_like, :destroy_like]
  before_action :check_owner!, only: [:new, :edit, :update, :destroy]

  # GET /@:name/items
  def index
    redirect_to user_path(name: @user)
  end

  # GET /@:name/items/new
  def new
    @article = Article.new
    @article_d = @article.decorate
  end

  # POST /@:name/items
  def create
    @article = Article.new
    article_builder = ArticleBuilder.new(@article)
    if article_builder.build(article_params)
      render_json @article
    else
      render_json @article, status: 400
    end
  end

  # GET /@:name/items/:id
  def show
    unless @article.published?
      check_owner!
      redirect_to edit_article_path(@article, name: current_user)
      return
    end

    view_countup

    respond_to do |format|
      format.html { render }
      format.json { render_json @article }
    end
  end

  # GET /@:name/items/:id/edit
  def edit
  end

  # PUT /@:name/items/:id
  def update
    article_builder = ArticleBuilder.new(@article)
    if article_builder.build(article_params)
      render_json @article
    else
      render_json @article, status: 400
    end
  end

  # DELETE /@:name/items/:id
  def destroy
    @article.destroy
    redirect_to user_path(name: current_user.name)
  end

  # POST /@:name/items/:id/like
  def create_like
    like = Like.find_or_initialize_by(
      user_id: current_user.id,
      target_type: 'Article',
      target_id: @article.id
    )
    if like.save
      @article.update_like_count
      render_json(article_id: @article.id, liked: true)
    else
      render_json({article_id: @article.id}, status: 400)
    end
  end

  # DELETE /@:name/items/:id/like
  def destroy_like
    like = Like.find_or_initialize_by(
      user_id: current_user.id,
      target_type: 'Article',
      target_id: @article.id
    )
    like.destroy
    @article.update_like_count
    head :no_content
  end

  # POST /@:name/items/preview.json
  def preview
    revision = Revision.new(
      user_id: current_user.id,
      title: 'preview',
      body: params[:body],
      revision_type: 1,
      note: ''
    )
    if revision.valid?
      render_json revision
    else
      render_json revision, status: 400
    end
  end

  private

  def set_user!
    @user = User.find_by!(name: params[:name])
  end

  def set_article!
    @article = @user.articles.find(params[:id] || params[:article_id])
    @article_d = @article.decorate
  end

  def article_params
    params.permit(:title, :tags_text, :body, :note, :publish_type).merge(user_id: current_user.id)
  end

  def check_owner!
    raise Errors::Forbidden unless @user == current_user
  end

  def view_countup
    list = session['visited_list'] || []
    @article.increment!(:view_count) unless list.include?(@article.id)
    session['visited_list'] = list.unshift(@article.id).uniq[0, 50]
  end
end
