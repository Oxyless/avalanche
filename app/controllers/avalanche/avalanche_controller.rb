module Avalanche
  class AvalancheController < ApplicationController
    def index
    end

    def mockup
    end

    def test
      render :json => { :cols => ["dawdadw"] }
    end

    def elements
      planified = Avalanche::AvalancheJob.where("avalanche_jobs.perform_at > ?", Time.now)
    end
  end
end
