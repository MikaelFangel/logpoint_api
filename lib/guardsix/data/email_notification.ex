defmodule Guardsix.Data.EmailNotification do
  @moduledoc """
  Builder for email notification structs.

  Wraps the [Email Notification for Alert Rules API](https://docs.guardsix.com/siem/product-docs/readme/siem_api_reference/email-notification-for-alert-rules).
  Start with `Guardsix.email_notification/2` and pipe through the builder
  functions to set subject, template, and other options.
  """

  alias Guardsix.Error

  @enforce_keys [:ids, :email_emails]
  defstruct [
    :ids,
    :email_emails,
    :email_subject,
    :email_template,
    :simple_view,
    :notify_email,
    :dispatch_option,
    :disable_search_link,
    :logo_enable,
    :logo_type,
    :logo_value,
    :threshold_option,
    :threshold_value
  ]

  @type t :: %__MODULE__{
          ids: [String.t()],
          email_emails: [String.t()],
          email_subject: String.t(),
          email_template: String.t(),
          simple_view: boolean() | nil,
          notify_email: boolean() | nil,
          dispatch_option: String.t() | nil,
          disable_search_link: boolean() | nil,
          logo_enable: boolean() | nil,
          logo_type: String.t() | nil,
          logo_value: String.t() | nil,
          threshold_option: String.t() | nil,
          threshold_value: number() | nil
        }

  @required_fields [:ids, :email_emails, :email_subject, :email_template]

  @spec validate(t()) :: :ok | {:error, Error.Validation.t()}
  def validate(%__MODULE__{} = notif) do
    errors =
      for field <- @required_fields,
          blank?(Map.get(notif, field)),
          into: %{},
          do: {to_string(field), "is required"}

    case errors do
      empty when map_size(empty) == 0 -> :ok
      errors -> {:error, Error.Validation.new(errors)}
    end
  end

  defp blank?(nil), do: true
  defp blank?([]), do: true
  defp blank?(_), do: false

  def new(ids, emails) when is_list(ids) and is_list(emails) do
    %__MODULE__{ids: ids, email_emails: emails}
  end

  def new(ids, email) when is_list(ids) and is_binary(email) do
    %__MODULE__{ids: ids, email_emails: [email]}
  end

  def subject(%__MODULE__{} = notif, subject), do: %{notif | email_subject: subject}
  def template(%__MODULE__{} = notif, template), do: %{notif | email_template: template}
  def simple_view(%__MODULE__{} = notif, enabled), do: %{notif | simple_view: enabled}
  def notify_email(%__MODULE__{} = notif, enabled), do: %{notif | notify_email: enabled}
  def dispatch_option(%__MODULE__{} = notif, option), do: %{notif | dispatch_option: option}

  def disable_search_link(%__MODULE__{} = notif, disabled), do: %{notif | disable_search_link: disabled}

  def logo(%__MODULE__{} = notif, type, value) do
    %{notif | logo_enable: true, logo_type: type, logo_value: value}
  end

  def threshold(%__MODULE__{} = notif, option, value) when is_atom(option) do
    %{notif | threshold_option: Atom.to_string(option), threshold_value: value}
  end

  @doc """
  Convert an `EmailNotification` struct into the flat map format expected by the Guardsix API.
  """
  def to_payload(%__MODULE__{} = notif) do
    %{
      ids: Jason.encode!(notif.ids),
      email_emails: Jason.encode!(notif.email_emails),
      subject: notif.email_subject,
      email_template: notif.email_template,
      simple_view: notif.simple_view,
      notify_email: notif.notify_email,
      dispatch_option: notif.dispatch_option,
      disable_search_link: notif.disable_search_link,
      logo_enable: notif.logo_enable,
      logo_type: notif.logo_type,
      logo: notif.logo_value,
      threshold_option: notif.threshold_option,
      threshold_value: notif.threshold_value
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
