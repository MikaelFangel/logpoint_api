defmodule LogpointApi.Data.Comment do
  @moduledoc false
  @enforce_keys :_id
  defstruct [:_id, comments: []]

  def new(id, comments) when is_list(comments) do
    %__MODULE__{_id: id, comments: comments}
  end

  def new(id, comment) when is_binary(comment) do
    %__MODULE__{_id: id, comments: [comment]}
  end
end
