class DeepseekChannel < ApplicationCable::Channel
  def subscribed
    connection_id = params[:connection_id]
    if connection_id
      stream_from "deepseek_channel_#{connection_id}"
    end
  end

  def unsubscribed
  end
end
