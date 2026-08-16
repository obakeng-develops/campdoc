class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    WideEvent.start(:job, job_class: job.class.name, job_id: job.job_id, queue: job.queue_name)
    block.call
    WideEvent.add(outcome: "success")
  rescue => error
    WideEvent.add(outcome: "error")
    WideEvent.add_error(error)
    raise
  ensure
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    WideEvent.emit(duration_ms: duration_ms)
  end
end
