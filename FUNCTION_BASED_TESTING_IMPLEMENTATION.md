# Function-Based Testing Implementation Plan

Implementation plan for adding LeetCode-style function-based testing to CP Server.

## Overview

Add support for function-based problems where users implement a function/class (e.g., `invertTree(TreeNode* root)`) instead of reading from STDIN/STDOUT. The system will:
- Provide template code (data structures + function skeleton)
- Merge user code with hidden test harness
- Run tests and output "OK" or "ERROR" per test case
- Reuse existing STDIN/STDOUT comparison logic

---

## Phase 1: Database Schema

### Migrations

- [ ] Create migration: `add_testing_mode_to_problems`
  - [ ] Add `testing_mode` column (string, default: 'stdin_stdout')
  - [ ] Add index on `testing_mode`
  - [ ] Run migration

- [ ] Create migration: `add_description_to_examples` (optional but recommended)
  - [ ] Add `description` column (text) to examples table
  - [ ] Used to show human-readable test case description for function-based problems
  - [ ] Example: "Input: [4,2,7,1,3,6,9], Expected: Inverted binary tree"
  - [ ] For STDIN/STDOUT problems, this can be null (output is shown instead)
  - [ ] Run migration

- [ ] Create migration: `create_problem_templates`
  - [ ] Create table with columns:
    - [ ] `problem_id` (foreign key)
    - [ ] `programming_language_id` (foreign key)
    - [ ] `template_code` (text, not null)
    - [ ] `function_signature` (string) - e.g., "TreeNode* invertTree(TreeNode* root)"
    - [ ] `created_at`, `updated_at`
  - [ ] Add unique index on `[problem_id, programming_language_id]`
  - [ ] Add foreign key constraints
  - [ ] Run migration

- [ ] Create migration: `create_problem_testers`
  - [ ] Create table with columns:
    - [ ] `problem_id` (foreign key)
    - [ ] `programming_language_id` (foreign key)
    - [ ] `tester_code` (text, not null)
    - [ ] `created_at`, `updated_at`
  - [ ] Add unique index on `[problem_id, programming_language_id]`
  - [ ] Add foreign key constraints
  - [ ] Run migration

---

## Phase 2: Models

### ProblemTemplate Model

- [ ] Create `app/app/models/problem_template.rb`
  - [ ] Add associations: `belongs_to :problem`, `belongs_to :programming_language`
  - [ ] Add validations:
    - [ ] `template_code` presence
    - [ ] `programming_language_id` uniqueness scoped to `problem_id`
  - [ ] Add method: `has_template?` (check if template_code is present)

### ProblemTester Model

- [ ] Create `app/app/models/problem_tester.rb`
  - [ ] Add associations: `belongs_to :problem`, `belongs_to :programming_language`
  - [ ] Add validations:
    - [ ] `tester_code` presence
    - [ ] `programming_language_id` uniqueness scoped to `problem_id`

### Update Problem Model

- [ ] Update `app/app/models/problem.rb`
  - [ ] Add enum: `enum testing_mode: { stdin_stdout: 'stdin_stdout', function: 'function' }`
  - [ ] Add associations:
    - [ ] `has_many :problem_templates, dependent: :destroy`
    - [ ] `has_many :problem_testers, dependent: :destroy`
  - [ ] Add scopes:
    - [ ] `scope :stdin_stdout_mode, -> { where(testing_mode: 'stdin_stdout') }`
    - [ ] `scope :function_mode, -> { where(testing_mode: 'function') }`
  - [ ] Add methods:
    - [ ] `def template_for(language)` - find template by language
    - [ ] `def tester_for(language)` - find tester by language
    - [ ] `def function_based?` - check if testing_mode == 'function'
    - [ ] `def available_languages_for_function_mode` - languages with templates

---

## Phase 3: Services

### FunctionBasedTestingService

- [ ] Create `app/app/services/function_based_testing_service.rb`
  - [ ] Add initialize method with params: `problem`, `language`, `user_code`, `example`
  - [ ] Add `execute` method:
    - [ ] Get template for language
    - [ ] Get tester for language
    - [ ] Combine: `user_code + "\n\n" + tester_code`
    - [ ] Write combined code to temp file
    - [ ] Compile if needed (C/C++)
    - [ ] Execute using NsjailExecutionService with example.input as STDIN
    - [ ] Return result hash with status, output, runtime
  - [ ] Add error handling:
    - [ ] Missing template → return error
    - [ ] Missing tester → return error
    - [ ] Compilation error → return compilation_error status
  - [ ] Add cleanup method for temp files

### Update SubmissionService

- [ ] Update `app/app/services/submission_service.rb`
  - [ ] Modify `execute` method to check `problem.testing_mode`
  - [ ] Route to appropriate execution:
    ```ruby
    if problem.function_based?
      execute_function_based
    else
      execute_stdin_stdout # existing logic
    end
    ```
  - [ ] Add `execute_function_based` private method:
    - [ ] Create FunctionBasedTestingService instance
    - [ ] Call execute and return result
  - [ ] Rename current logic to `execute_stdin_stdout` method

### Update Submission Model

- [ ] Update `app/app/models/submission.rb`
  - [ ] Update `run_with_interpreter!` to handle both modes
  - [ ] Update `run_with_compiler!` to handle both modes
  - [ ] Ensure the execution loops work for function-based problems

---

## Phase 4: Admin Interface

### Admin Routes

- [ ] Update `config/routes.rb`
  - [ ] Add nested routes under admin/problems:
    ```ruby
    namespace :admin do
      resources :problems do
        resources :templates, controller: 'problem_template'
        resources :testers, controller: 'problem_tester'
      end
    end
    ```

### Admin::ProblemTemplateController

- [ ] Create `app/app/controllers/admin/problem_template_controller.rb`
  - [ ] Add `index` action - list templates for a problem
  - [ ] Add `new` action - show form for new template
  - [ ] Add `create` action - save new template
  - [ ] Add `edit` action - show edit form
  - [ ] Add `update` action - save changes
  - [ ] Add `destroy` action - delete template
  - [ ] Add strong parameters
  - [ ] Add before_action: `require_admin`, `set_problem`

### Admin::ProblemTesterController

- [ ] Create `app/app/controllers/admin/problem_tester_controller.rb`
  - [ ] Add `index` action - list testers for a problem
  - [ ] Add `new` action - show form for new tester
  - [ ] Add `create` action - save new tester
  - [ ] Add `edit` action - show edit form
  - [ ] Add `update` action - save changes
  - [ ] Add `destroy` action - delete tester
  - [ ] Add strong parameters
  - [ ] Add before_action: `require_admin`, `set_problem`

### Update Admin::ProblemController

- [ ] Update `app/app/controllers/admin/problem_controller.rb` (if exists)
  - [ ] Add `testing_mode` to permitted parameters
  - [ ] Update create/edit actions to handle testing_mode

---

## Phase 5: Admin Views

### Template Views

- [ ] Create `app/app/views/admin/problem_template/index.html.erb`
  - [ ] List all templates for the problem (grouped by language)
  - [ ] Show "Add Template" button for each missing language
  - [ ] Show edit/delete buttons for existing templates
  - [ ] Display function signature

- [ ] Create `app/app/views/admin/problem_template/new.html.erb`
  - [ ] Show form with:
    - [ ] Language dropdown (only languages without template)
    - [ ] Textarea for template_code (large, with monospace font)
    - [ ] Text field for function_signature
    - [ ] Submit button

- [ ] Create `app/app/views/admin/problem_template/edit.html.erb`
  - [ ] Similar to new, but pre-filled with existing data
  - [ ] Can't change language (disabled field)

- [ ] Create `app/app/views/admin/problem_template/_form.html.erb`
  - [ ] Shared form partial for new/edit
  - [ ] Use code editor (CodeMirror/Monaco) if available

### Tester Views

- [ ] Create `app/app/views/admin/problem_tester/index.html.erb`
  - [ ] List all testers for the problem (grouped by language)
  - [ ] Show "Add Tester" button for each missing language
  - [ ] Show edit/delete buttons for existing testers
  - [ ] Show test case count (if we add that field later)

- [ ] Create `app/app/views/admin/problem_tester/new.html.erb`
  - [ ] Show form with:
    - [ ] Language dropdown (only languages without tester)
    - [ ] Large textarea for tester_code
    - [ ] Instructions on expected output format ("OK" or "ERROR")
    - [ ] Submit button

- [ ] Create `app/app/views/admin/problem_tester/edit.html.erb`
  - [ ] Similar to new, but pre-filled
  - [ ] Can't change language

- [ ] Create `app/app/views/admin/problem_tester/_form.html.erb`
  - [ ] Shared form partial
  - [ ] Use code editor if available

### Update Problem Form

- [ ] Update `app/app/views/admin/problems/_form.html.erb` (or wherever problem form is)
  - [ ] Add radio buttons for testing_mode:
    - [ ] "STDIN/STDOUT Mode" (default)
    - [ ] "Function-Based Mode"
  - [ ] Show links to manage templates/testers when function mode is selected
  - [ ] Add JavaScript to show/hide relevant sections based on mode

### Update Example/Test Case Forms

- [ ] Update example form to include `description` field
  - [ ] For function-based problems: description is required and shown to users
  - [ ] For STDIN/STDOUT problems: description is optional (output is shown)
  - [ ] Add help text explaining when to use description
  - [ ] Show/hide description field based on problem's testing_mode

---

## Phase 6: User Interface

### Update Problem Show Page

- [ ] Update `app/app/views/problem/show.html.erb`
  - [ ] Check if problem is function-based
  - [ ] For function-based problems:
    - [ ] Display "Testing Mode: Function-Based" badge/notice
    - [ ] Show function signature prominently
    - [ ] Add "Template Code" section (collapsible)
    - [ ] Show available languages (only those with templates)
    - [ ] Pre-populate code editor with template when language is selected
    - [ ] **Hide actual output ("OK"/"ERROR") in example test cases**
    - [ ] Show only input data or test case description to users
    - [ ] Display example format like: "Test Case 1: [4,2,7,1,3,6,9] → Tree should be inverted"
  - [ ] For STDIN/STDOUT problems:
    - [ ] Keep existing display (show input/output as normal)

### Update Code Editor Behavior

- [ ] Update JavaScript for code editor (`app/app/assets/javascripts/` or views)
  - [ ] On language change:
    - [ ] If function-based: fetch and display template for that language
    - [ ] If STDIN/STDOUT: keep empty or show boilerplate
  - [ ] Add API endpoint to fetch template by language:
    - [ ] `GET /problems/:id/template?language_id=X`

### Create Template Endpoint

- [ ] Update `app/app/controllers/problem_controller.rb`
  - [ ] Add `template` action:
    - [ ] Find problem and language
    - [ ] Return template_code as JSON
    - [ ] Return 404 if no template exists
  - [ ] Add route: `get 'problems/:id/template', to: 'problem#template'`

### Update Language Selection

- [ ] Update language dropdown for function-based problems
  - [ ] Only show languages that have templates
  - [ ] Add tooltip: "This problem only supports C and C++"
  - [ ] Disable languages without templates

---

## Phase 7: Testing

### Unit Tests

- [ ] Test ProblemTemplate model
  - [ ] Test validations
  - [ ] Test associations
  - [ ] Test uniqueness constraint

- [ ] Test ProblemTester model
  - [ ] Test validations
  - [ ] Test associations

- [ ] Test Problem model additions
  - [ ] Test enum
  - [ ] Test scopes
  - [ ] Test helper methods (`template_for`, `tester_for`)

- [ ] Test FunctionBasedTestingService
  - [ ] Test code merging
  - [ ] Test execution
  - [ ] Test error handling

### Integration Tests

- [ ] Test full submission flow for function-based problem
  - [ ] Create test problem with template and tester
  - [ ] Submit correct solution → expect ACCEPTED
  - [ ] Submit wrong solution → expect WRONG_ANSWER
  - [ ] Submit solution without proper function → expect compilation/runtime error

- [ ] Test admin template/tester management
  - [ ] Create template via admin interface
  - [ ] Edit template
  - [ ] Delete template
  - [ ] Same for testers

---

## Phase 8: Example Problems

### Create Binary Tree Inversion Problem

- [ ] Create problem in database (testing_mode: 'function')
  - [ ] Add problem description
  - [ ] Add examples with:
    - [ ] `input`: "[4,2,7,1,3,6,9]\n" (what test harness reads)
    - [ ] `output`: "OK\n" (internal - for comparison)
    - [ ] `description`: "Input tree: [4,2,7,1,3,6,9], Expected: Inverted tree [4,7,2,9,6,3,1]" (shown to user)
    - [ ] `is_hidden`: false for first few, true for others
  - [ ] Set difficulty, time/memory limits

- [ ] Create C++ template
  - [ ] TreeNode struct definition
  - [ ] buildTree helper function
  - [ ] Solution class skeleton with `TreeNode* invertTree(TreeNode* root)`

- [ ] Create C++ tester
  - [ ] Parse input array from STDIN
  - [ ] Build tree from array
  - [ ] Call user's invertTree
  - [ ] Validate inversion
  - [ ] Output "OK" or "ERROR"

- [ ] Create C template
  - [ ] Similar to C++ but C-style

- [ ] Test the problem end-to-end
  - [ ] Submit correct solution
  - [ ] Submit wrong solution
  - [ ] Verify all test cases run

### Create Linked List Reversal Problem

- [ ] Create problem in database
- [ ] Create C++ template with ListNode
- [ ] Create C++ tester
- [ ] Create C template
- [ ] Test end-to-end

---

## Phase 9: Documentation

### User Documentation

- [ ] Create guide: "How Function-Based Problems Work"
  - [ ] Explain the difference from STDIN/STDOUT
  - [ ] Show example of what user sees
  - [ ] Explain template code
  - [ ] Explain function signature

- [ ] Update README.md
  - [ ] Add section about function-based testing
  - [ ] List supported problem types

### Admin Documentation

- [ ] Create guide: "Creating Function-Based Problems"
  - [ ] Step-by-step instructions
  - [ ] Template writing guidelines
  - [ ] Tester writing guidelines
  - [ ] Best practices for test cases
  - [ ] Common pitfalls

- [ ] Create template/tester examples repository
  - [ ] TreeNode template for C/C++
  - [ ] ListNode template for C/C++
  - [ ] Array helpers
  - [ ] Common tester patterns

---

## Phase 10: Polish & Refinement

### Performance

- [ ] Add database indexes if queries are slow
- [ ] Consider caching templates (they rarely change)

### Security

- [ ] Ensure testers can't be accessed by non-admins
- [ ] Validate that user code can't escape the sandbox
- [ ] Test malicious code in function-based mode

### User Experience

- [ ] Add loading indicators when fetching templates
- [ ] Add syntax highlighting in code editor
- [ ] Add "Test with Custom Input" feature (if desired)
- [ ] Show which language is recommended/required

### Error Messages

- [ ] Improve error messages when template is missing
- [ ] Improve error messages when tester is missing
- [ ] Show helpful hints if user doesn't implement required function

---

## Deployment Checklist

- [ ] Run all migrations in production
- [ ] Verify no data loss for existing problems
- [ ] Test one function-based problem in production
- [ ] Monitor logs for errors
- [ ] Announce new feature to users
- [ ] Create tutorial video/guide

---

## Future Enhancements (Optional)

- [ ] Support for multiple function signatures per problem
- [ ] Visual test case editor (instead of raw STDIN)
- [ ] Template validation tool (check syntax before saving)
- [ ] More complex data structures (graphs, heaps, etc.)
- [ ] Support for Python, JavaScript function-based problems
- [ ] Class-based problems with multiple methods (e.g., implement a Stack)
- [ ] Interactive debugger for function-based problems
- [ ] Allow users to download template for local testing

---

## Notes

- Start with C and C++ only
- Keep STDIN/STDOUT problems working (no breaking changes)
- Test thoroughly before adding more problem types
- Each template should be tested with both correct and incorrect solutions
- Output format must be exactly "OK\n" or "ERROR\n" for tests to work
- **IMPORTANT**: Users should NEVER see "OK" or "ERROR" as expected output
  - For STDIN/STDOUT: Show actual input/output
  - For function-based: Show description or input only, hide the "OK\n" output
- Examples table:
  - `input`: What the test harness receives (serialized data)
  - `output`: "OK\n" (internal, for comparison, hidden from users)
  - `description`: Human-readable explanation (shown to users for function-based problems)
