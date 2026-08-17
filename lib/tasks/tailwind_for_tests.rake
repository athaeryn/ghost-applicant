# Build Tailwind CSS before running the test suite so view tests can resolve the
# compiled stylesheet.
Rake::Task["test"].enhance([ "tailwindcss:build" ]) if Rake::Task.task_defined?("test")
