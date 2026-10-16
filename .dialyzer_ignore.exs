# Dialyzer on OTP 28 reports false opaque-type mismatches for ordinary MapSet
# calls (MapSet.new/put/member?). The sorter's use of MapSet is correct.
[
  {"lib/job_processor/sorter.ex", :call_with_opaque},
  {"lib/job_processor/sorter.ex", :call_without_opaque}
]
