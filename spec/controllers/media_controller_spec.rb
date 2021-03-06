require "rails_helper"

RSpec.describe MediaController, type: :controller do

  describe "GET 'download'" do
    before(:each) do
      allow(controller).to receive_messages(requested_via_private_vhost?: false)
    end

    context "with a valid clean file" do
      before :each do
        @asset = FactoryGirl.create(:clean_asset)
      end

      def do_get
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
      end

      it "should be successful" do
        do_get
        expect(response).to be_success
      end

      it "should send the file using send_file" do
        expect(controller).to receive(:send_file).with(@asset.file.path, :disposition => "inline")
        allow(controller).to receive(:render) # prevent template_not_found errors because we intercepted send_file

        do_get
      end

      it "should have the correct content type" do
        do_get
        expect(response.headers["Content-Type"]).to eq("image/png")
      end

      it "should set the cache-control headers to 24 hours" do
        do_get

        expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
      end

      context "when the file name in the URL represents an old version" do
        let(:old_file_name) { "an_old_filename.pdf" }

        before do
          allow(Asset).to receive(:find).with(@asset.id.to_s).and_return(@asset)
          allow(@asset).to receive(:filename_valid?).and_return(true)
        end

        it "redirects to the new file name" do
          get :download, id: @asset.id, filename: old_file_name

          expect(response.location).to match(%r(\A/media/#{@asset.id}/asset.png))
        end
      end

      context "when the file name in the URL is invalid" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        it "redirects to the new file name" do
          get :download, id: @asset.id, filename: invalid_file_name

          expect(response).to be_not_found
        end
      end
    end

    context "with an unscanned file" do
      before :each do
        @asset = FactoryGirl.create(:asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
        expect(response.code.to_i).to eq(404)
      end
    end

    context "with an infected file" do
      before :each do
        @asset = FactoryGirl.create(:infected_asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
        expect(response.code.to_i).to eq(404)
      end
    end

    context "with a URL containing an invalid ID" do
      it "should return a 404" do
        get :download, :id => "1234556678895332452345", :filename => "something.jpg"
        expect(response.code.to_i).to eq(404)
      end
    end

    context "access limiting on the public interface" do
      before(:each) do
        @restricted_asset = FactoryGirl.create(:access_limited_asset, organisation_slug: 'example-slug')
        @unrestricted_asset = FactoryGirl.create(:clean_asset)
      end

      it "404s requests to access limited documents" do
        get :download, id: @restricted_asset.id.to_s, filename: 'asset.png'
        expect(response.status).to eq(404)
      end

      it "permits access to unrestricted documents" do
        get :download, id: @unrestricted_asset.id.to_s, filename: 'asset.png'
        expect(response).to be_success
      end
    end

    context "access limiting on the private interface" do
      before(:each) do
        allow(controller).to receive_messages(requested_via_private_vhost?: true)

        @asset = FactoryGirl.create(:access_limited_asset, organisation_slug: 'correct-organisation-slug')
      end

      it "bounces anonymous users to sign-on" do
        expect(controller).to receive(:require_signin_permission!)

        get :download, id: @asset.id.to_s, filename: 'asset.png'
      end

      it "404s requests to access limited documents if the user has the wrong organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'incorrect-organisation-slug')
        login_as(user)

        get :download, id: @asset.id.to_s, filename: 'asset.png'

        expect(response.status).to eq(404)
      end

      it "permits access to access limited documents if the user has the right organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'correct-organisation-slug')
        login_as(user)

        get :download, id: @asset.id.to_s, filename: 'asset.png'

        expect(response).to be_success
      end
    end
  end
end
