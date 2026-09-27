# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe "Submission test", type: :request do
  def uploaded_utf8_source(contents, ext: ".py")
    tempfile = Tempfile.new(["solution", ext])
    tempfile.binmode
    tempfile.write(contents.dup.force_encoding(Encoding::ASCII_8BIT))
    tempfile.rewind
    [tempfile, Rack::Test::UploadedFile.new(tempfile.path, "text/plain")]
  end

  let(:user) { create(:user) }
  let(:language) { create(:programming_language, :python) }
  let(:problem) { create(:problem) }
  let!(:example) do
    create(:example, problem: problem, input: "año", output: "año", is_hidden: false, sort_order: 1)
  end

  before { sign_in user }

  it "returns UTF-8 output from an uploaded source file without raising" do
    service = instance_double(SubmissionService)
    allow(SubmissionService).to receive(:new).and_return(service)
    allow(service).to receive(:execute).and_return(
      status: "passed",
      output: "año".dup.force_encoding(Encoding::ASCII_8BIT),
      runtime: 3,
      error_message: nil
    )

    tempfile, upload = uploaded_utf8_source("print('año')")

    post problem_test_path, params: {
      problem_id: problem.id,
      programming_language_id: language.id,
      source_code: upload
    }, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body["success"]).to eq(true)
    expect(body["test_results"].first["actual_output"]).to eq("año")
    expect(body["test_results"].first["input"]).to eq("año")
    expect(body["test_results"].first["expected_output"]).to eq("año")
  ensure
    tempfile.close!
  end
end
