require "../../src/controllers/tasks"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe TasksController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  let(actor) { register.actor }

  describe "GET /tasks" do
    it "returns 401 if not authorized" do
      get "/tasks"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/tasks"
        expect(response.status_code).to eq(200)
      end

      it "does not render any tasks" do
        get "/tasks", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//table/tr")).to be_empty
      end

      it "does not render any tasks" do
        get "/tasks", ACCEPT_JSON
        expect(JSON.parse(response.body).dig("tasks")).to be_empty
      end

      context "given a task" do
        let_create!(:task)

        it "renders a row" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//table/tr")).not_to be_empty
        end

        it "renders an object" do
          get "/tasks", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("tasks")).not_to be_empty
        end

        it "renders the task class" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).to have("Task")
        end

        it "renders the task class" do
          get "/tasks", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("tasks", 0, "type")).to eq("Task")
        end

        it "renders the task status" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).to have("The next run is imminent.")
        end

        it "renders the task status" do
          get "/tasks", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("tasks", 0, "status")).to eq("The next run is imminent.")
        end

        context "given a task that fetches content" do
          class TestFetcher < Task
            include Task::Fetch::Fetcher

            class State
              def last_success_at
                Time.utc
              end
            end

            property state = State.new

            def initialize
              super(source_iri: "https://source", subject_iri: "https://subject")
            end

            def path_to
              "/path"
            end
          end

          let(task) { TestFetcher.new.save }

          it "renders the path to the subject page" do
            get "/tasks", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td/a/@href")).to have("/path")
          end

          it "renders the path to the subject page" do
            get "/tasks", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("tasks", 0, "path")).to eq("/path")
          end

          it "renders the task status" do
            get "/tasks", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).to have("The next check for new posts is imminent.")
          end

          it "renders the task status" do
            get "/tasks", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("tasks", 0, "status")).to eq("The next check for new posts is imminent.")
          end

          it "renders the subject" do
            get "/tasks", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).to have("https://subject")
          end

          it "renders the subject" do
            get "/tasks", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("tasks", 0, "subject")).to eq("https://subject")
          end
        end

        context "with a subject" do
          before_each { task.assign(subject_iri: "https://subject").save }

          it "renders the subject" do
            get "/tasks", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).to have("https://subject")
          end

          it "renders the subject" do
            get "/tasks", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("tasks", 0, "subject")).to eq("https://subject")
          end
        end

        context "that is complete" do
          before_each { task.assign(complete: true).save }

          it "does not render the task" do
            get "/tasks", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//table/tr")).to be_empty
          end

          it "does not render the task" do
            get "/tasks", ACCEPT_JSON
            expect(JSON.parse(response.body).dig("tasks")).to be_empty
          end
        end

        it "does not render any empty cells" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//table/tr/td")).not_to have("")
        end
      end

      it "renders idle status" do
        get "/tasks", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class, 'green') and contains(@class, 'message')]//div[@class='header']")).to have("All Tasks Idle")
      end

      it "includes idle status" do
        get "/tasks", ACCEPT_JSON
        json = JSON.parse(response.body)
        expect(json.dig("status", "type")).to eq("idle")
        expect(json.dig("status", "message")).to eq("No tasks are running or scheduled to start soon.")
      end

      context "with running task" do
        let_create!(:task, running: true, complete: false)

        it "renders running status" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class, 'red') and contains(@class, 'message')]//div[@class='header']")).to have("Tasks Running")
        end

        it "includes running status" do
          get "/tasks", ACCEPT_JSON
          json = JSON.parse(response.body)
          expect(json.dig("status", "type")).to eq("running")
          expect(json.dig("status", "message")).to eq("1 task currently running.")
        end
      end

      context "with task scheduled soon" do
        let_create!(:task, running: false, complete: false, next_attempt_at: 30.seconds.from_now)

        it "renders scheduled status" do
          get "/tasks", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class, 'yellow') and contains(@class, 'message')]//div[@class='header']")).to have("Tasks Starting Soon")
        end

        it "includes scheduled status" do
          get "/tasks", ACCEPT_JSON
          json = JSON.parse(response.body)
          expect(json.dig("status", "type")).to eq("scheduled")
          expect(json.dig("status", "message")).to eq("1 task scheduled to run within one minute.")
        end
      end
    end
  end
end
