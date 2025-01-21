# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProblemController, type: :controller do
  let(:user) { create(:user) }
  let(:problem) { create(:problem) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #show' do
    before do
      create(:example, problem: problem)
    end

    it 'returns http success' do
      get :show, params: { id: problem.id }

      expect(response).to have_http_status(:success)
    end
  end
end
