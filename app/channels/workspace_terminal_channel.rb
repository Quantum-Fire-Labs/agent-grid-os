require "pty"

class WorkspaceTerminalChannel < ApplicationCable::Channel
  def subscribed
    @agent = current_user.account.agents.find(params[:agent_id])
    reject unless @agent.workspace_enabled?
    stream_for @agent
    start_session
  end

  def receive(data)
    if data["resize"]
      set_pty_size(data["resize"]["cols"], data["resize"]["rows"])
    elsif data["input"]
      @writer&.write(data["input"])
    end
  end

  def unsubscribed
    stop_session
  end

  private
    def start_session
      container = Agent::Workspace.new(@agent).container_name
      @reader, @writer, @pid = PTY.spawn("docker", "exec", "-it", container, "bash")

      cols = params[:cols].to_i
      rows = params[:rows].to_i
      set_pty_size(cols, rows) if cols > 0 && rows > 0

      initial_command = params[:command]
      @command_sent = initial_command.blank?

      @thread = Thread.new do
        while (chunk = @reader.readpartial(4096))
          WorkspaceTerminalChannel.broadcast_to(@agent, { output: chunk })

          if !@command_sent && chunk.include?("$")
            @command_sent = true
            @writer.write(initial_command + "\n")
          end
        end
      rescue EOFError, Errno::EIO
        # PTY closed
      ensure
        WorkspaceTerminalChannel.broadcast_to(@agent, { event: "exit" })
      end
    end

    def stop_session
      Process.kill("TERM", @pid) if @pid rescue nil
      @thread&.kill
    end

    TIOCSWINSZ = 0x5414 # Linux ioctl for setting window size

    def set_pty_size(cols, rows)
      return unless @reader

      winsize = [ rows.to_i, cols.to_i, 0, 0 ].pack("SSSS")
      @reader.ioctl(TIOCSWINSZ, winsize)
    rescue
      # Best effort
    end
end
