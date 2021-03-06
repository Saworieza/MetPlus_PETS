require 'rails_helper'
include ServiceStubHelpers::Cruncher

RSpec.shared_examples 'denies access to unauthorized people' do
  context 'agency people' do
    it_behaves_like 'unauthorized request' do
      let(:user) { agency_admin }
    end

    it_behaves_like 'unauthorized request' do
      let(:user) { job_developer }
    end

    it_behaves_like 'unauthorized request' do
      let(:user) { case_manager }
    end
  end

  context 'company people who don\'t belong to the job posting company' do
    it_behaves_like 'unauthorized request' do
      let(:user) { company_contact2 }
    end

    it_behaves_like 'unauthorized request' do
      let(:user) { company_admin2 }
    end
  end

  context 'job seeker' do
    it_behaves_like 'unauthorized request' do
      let(:user) { job_seeker }
    end
  end
end

RSpec.describe JobApplicationsController, type: :controller do
  let(:company)       { FactoryGirl.create(:company) }
  let(:job)           { FactoryGirl.create(:job, company: company) }
  let(:job_seeker)    { FactoryGirl.create(:job_seeker) }
  let(:job_seeker2)   { FactoryGirl.create(:job_seeker) }
  let!(:company_admin) { FactoryGirl.create(:company_admin, company: company) }
  let(:company_contact) { FactoryGirl.create(:company_contact, company: company) }
  let(:inactive_application) do
    FactoryGirl.create(:job_application,
                       job: job, job_seeker: job_seeker2,
                       status: 'accepted')
  end
  let(:valid_application) do
    FactoryGirl.create(:job_application, job: job, job_seeker: job_seeker)
  end
  let(:agency)       { FactoryGirl.create(:agency) }
  let(:agency_admin) { FactoryGirl.create(:agency_admin, agency: agency) }
  let(:company2)     { FactoryGirl.create(:company) }
  let(:company_admin2) do
    FactoryGirl.create(:company_admin,
                       company: company2)
  end
  let(:company_contact2) do
    FactoryGirl.create(:company_contact,
                       company: company2)
  end
  let(:job_developer) { FactoryGirl.create(:job_developer, agency: agency) }
  let(:case_manager)  { FactoryGirl.create(:case_manager, agency: agency) }

  before(:each) do
    stub_cruncher_authenticate
    stub_cruncher_job_create
  end

  describe 'GET #show' do
    let(:request) { get :show, id: valid_application }

    context 'unauthenticated' do
      it_behaves_like 'unauthenticated request'
    end

    context 'authenticated' do
      describe 'authorized access' do
        before do
          sign_in company_admin
          request
        end

        it 'should return http success' do
          expect(response).to have_http_status(200)
        end

        it 'renders the show template' do
          expect(response).to render_template(:show)
        end
      end

      describe 'unauthorized access' do
        it_behaves_like 'denies access to unauthorized people'
      end
    end
  end

  describe 'PATCH #accept' do
    let(:request) { patch :accept, id: valid_application }

    context 'unauthenticated' do
      it_behaves_like 'unauthenticated request'
    end

    context 'authenticated' do
      describe 'authorized access' do
        before(:each) do
          sign_in company_admin
        end

        context 'inactive job application' do
          before(:each) do
            patch :accept, id: inactive_application
          end

          it 'show a flash message of type alert' do
            expect(flash[:alert]).to eq 'Invalid action on'\
                ' inactive job application.'
          end

          it 'redirect to the specific job show page' do
            expect(response).to redirect_to(job_url(inactive_application.job))
          end
        end

        context 'valid job application accepted' do
          before(:each) do
            expect_any_instance_of(JobApplication).to receive(:accept)
            request
          end

          it 'show a flash message of type info' do
            expect(flash[:info]).to eq 'Job application accepted.'
          end

          it 'redirect to the specific job show page' do
            expect(response).to redirect_to(job_url(valid_application.job))
          end
        end
      end

      describe 'unauthorized access' do
        it_behaves_like 'denies access to unauthorized people'
      end
    end
  end

  describe 'PATCH #reject' do
    let(:request) do
      patch :reject, id: valid_application,
                     reason_for_rejection: 'Skills did not match'
    end

    context 'unauthenticated' do
      it_behaves_like 'unauthenticated request'
    end

    context 'authenticated' do
      describe 'authorized access' do
        before(:each) do
          sign_in company_admin
        end

        context 'inactive job application' do
          before(:each) do
            patch :reject, id: inactive_application
          end

          it 'show a flash message of type alert' do
            expect(flash[:alert]).to eq 'Cannot reject an '\
              'inactive job application.'
          end

          it 'redirect to the specific job application show page' do
            expect(response).to redirect_to(application_path(inactive_application))
          end
        end

        context 'valid job application rejected' do
          before(:each) do
            expect_any_instance_of(JobApplication).to receive(:reject)
            request
          end

          it 'stores rejection in db' do
            app = JobApplication.find(valid_application.id)
            expect(app.reason_for_rejection).to eq 'Skills did not match'
          end

          it 'show a flash message of type notice' do
            expect(flash[:notice]).to eq 'Job application rejected.'
          end

          it 'redirect to the specific job application show page' do
            expect(response).to redirect_to(job_url(valid_application.job))
          end
        end
      end

      describe 'unauthorized access' do
        it_behaves_like 'denies access to unauthorized people'
      end
    end
  end

  describe 'PATCH #process_application' do
    let(:request) { patch :process_application, id: valid_application }

    context 'unauthenticated' do
      it_behaves_like 'unauthenticated request'
    end

    context 'authenticated' do
      describe 'authorized access' do
        before(:each) do
          sign_in company_admin
        end

        context 'inactive job application' do
          before(:each) do
            patch :process_application, id: inactive_application
          end

          it 'show a flash message of type alert' do
            expect(flash[:alert]).to eq 'Invalid action on'\
                ' inactive job application.'
          end

          it 'redirect to the specific job show page' do
            expect(response).to redirect_to(job_url(inactive_application.job))
          end
        end

        context 'valid job application started processing' do
          before(:each) do
            expect_any_instance_of(JobApplication).to receive(:process)
            request
          end

          it 'show a flash message of type info' do
            expect(flash[:info]).to eq 'Job application processing.'
          end

          it 'redirect to the specific job show page' do
            expect(response).to redirect_to(job_url(valid_application.job))
          end
        end
      end

      describe 'unauthorized access' do
        it_behaves_like 'denies access to unauthorized people'
      end
    end
  end

  describe 'GET #list' do
    let(:job1) { FactoryGirl.create(:job) }
    let(:job2) { FactoryGirl.create(:job) }
    let(:job3) { FactoryGirl.create(:job) }
    let(:app1) do
      FactoryGirl.create(:job_application, job: job1, job_seeker: job_seeker)
    end
    let(:app2) do
      FactoryGirl.create(:job_application, job: job2, job_seeker: job_seeker)
    end
    let(:app3) do
      FactoryGirl.create(:job_application, job: job3, job_seeker: job_seeker)
    end
    let(:app4) do
      FactoryGirl.create(:job_application,
                         job: job3, job_seeker: FactoryGirl.create(:job_seeker))
    end

    before(:each) do
      xhr :get, :list, type: 'job_seeker-default', entity_id: job_seeker
    end

    it 'assigns jobs for view' do
      expect(assigns(:job_applications)).to include(app1, app2, app3)
      expect(assigns(:job_applications)).not_to include(app4)
    end

    it 'renders partial for applications' do
      expect(response).to render_template(partial: 'jobs/_applied_job_list')
    end
  end
end
