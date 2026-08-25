defmodule Guardsix.Data.Rule do
  @moduledoc """
  Builder for alert rule structs.

  Start with `Guardsix.rule/1` and pipe through the builder functions
  to set fields. Pass the result to `AlertRule.create/2`.
  """

  alias Guardsix.Error

  @enforce_keys [:name]
  defstruct [
    :name,
    :description,
    :query,
    :time_range_day,
    :time_range_hour,
    :time_range_minute,
    :repos,
    :limit,
    :search_interval,
    :delay_interval,
    :throttling_field,
    :throttling_time_range,
    :threshold_option,
    :threshold_value,
    :risk_level,
    :aggregation_type,
    :assignee,
    :jinja_template,
    mitre_tags: [],
    log_sources: [],
    metadata: %{},
    user_groups: [],
    flush_on_trigger: false,
    throttling_enabled: false,
    apply_jinja_template: false,
    simple_view: false,
    foureyes: false
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          query: String.t() | nil,
          time_range_day: non_neg_integer() | nil,
          time_range_hour: non_neg_integer() | nil,
          time_range_minute: non_neg_integer() | nil,
          repos: [String.t()] | nil,
          limit: non_neg_integer() | nil,
          search_interval: non_neg_integer() | nil,
          delay_interval: non_neg_integer() | nil,
          throttling_field: String.t() | nil,
          throttling_time_range: non_neg_integer() | nil,
          threshold_option: String.t() | nil,
          threshold_value: number() | nil,
          risk_level: String.t() | nil,
          aggregation_type: String.t() | nil,
          assignee: String.t() | nil,
          jinja_template: String.t() | nil,
          mitre_tags: [String.t()],
          log_sources: [String.t()],
          metadata: map(),
          user_groups: [String.t()],
          flush_on_trigger: boolean(),
          throttling_enabled: boolean(),
          apply_jinja_template: boolean(),
          simple_view: boolean(),
          foureyes: boolean()
        }

  @required_fields [
    :name,
    :query,
    :repos,
    :threshold_option,
    :threshold_value,
    :risk_level,
    :aggregation_type,
    :assignee
  ]

  @spec validate(t()) :: :ok | {:error, Error.Validation.t()}
  def validate(%__MODULE__{} = rule) do
    field_errors =
      for field <- @required_fields,
          blank?(Map.get(rule, field)),
          into: %{},
          do: {to_string(field), "is required"}

    time_range_errors =
      if blank?(rule.time_range_day) and blank?(rule.time_range_hour) and blank?(rule.time_range_minute) do
        %{"time_range" => "at least one of time_range_day, time_range_hour, or time_range_minute is required"}
      else
        %{}
      end

    case Map.merge(field_errors, time_range_errors) do
      empty when map_size(empty) == 0 -> :ok
      errors -> {:error, Error.Validation.new(errors)}
    end
  end

  defp blank?(nil), do: true
  defp blank?([]), do: true
  defp blank?(_), do: false

  def new(name) when is_binary(name) do
    %__MODULE__{name: name}
  end

  def description(%__MODULE__{} = rule, description), do: %{rule | description: description}
  def query(%__MODULE__{} = rule, query), do: %{rule | query: query}

  def time_range(rule, value, unit \\ :minute)

  def time_range(%__MODULE__{} = rule, value, :day) when is_integer(value) and value in 1..30,
    do: %{rule | time_range_day: value, time_range_hour: nil, time_range_minute: nil}

  def time_range(%__MODULE__{} = rule, value, :hour) when is_integer(value) and value > 720,
    do: time_range(rule, div(value, 24), :day)

  def time_range(%__MODULE__{} = rule, value, :hour) when is_integer(value) and value in 1..720,
    do: %{rule | time_range_hour: value, time_range_day: nil, time_range_minute: nil}

  def time_range(%__MODULE__{} = rule, value, :minute) when is_integer(value) and value >= 60,
    do: time_range(rule, div(value, 60), :hour)

  def time_range(%__MODULE__{} = rule, value, :minute) when is_integer(value) and value in 1..59,
    do: %{rule | time_range_minute: value, time_range_day: nil, time_range_hour: nil}

  def repos(%__MODULE__{} = rule, repos) when is_list(repos), do: %{rule | repos: repos}
  def limit(%__MODULE__{} = rule, limit) when is_integer(limit), do: %{rule | limit: limit}

  def search_interval(%__MODULE__{} = rule, minutes) when is_integer(minutes), do: %{rule | search_interval: minutes}

  def delay_interval(%__MODULE__{} = rule, minutes) when is_integer(minutes), do: %{rule | delay_interval: minutes}

  def flush_on_trigger(%__MODULE__{} = rule, enabled) when is_boolean(enabled), do: %{rule | flush_on_trigger: enabled}

  def throttling(%__MODULE__{} = rule, field, time_range) when is_binary(field) and is_integer(time_range) do
    %{rule | throttling_enabled: true, throttling_field: field, throttling_time_range: time_range}
  end

  def threshold(%__MODULE__{} = rule, option, value) when is_atom(option) do
    %{rule | threshold_option: Atom.to_string(option), threshold_value: value}
  end

  def risk_level(%__MODULE__{} = rule, level), do: %{rule | risk_level: level}

  def aggregation_type(%__MODULE__{} = rule, type), do: %{rule | aggregation_type: type}

  def mitre_tags(%__MODULE__{} = rule, tags) when is_list(tags), do: %{rule | mitre_tags: tags}

  def log_sources(%__MODULE__{} = rule, sources) when is_list(sources), do: %{rule | log_sources: sources}

  def metadata(%__MODULE__{} = rule, metadata) when is_map(metadata), do: %{rule | metadata: metadata}

  def assignee(%__MODULE__{} = rule, assignee), do: %{rule | assignee: assignee}

  def user_groups(%__MODULE__{} = rule, groups) when is_list(groups), do: %{rule | user_groups: groups}

  def jinja_template(%__MODULE__{} = rule, template), do: %{rule | jinja_template: template, apply_jinja_template: true}

  def simple_view(%__MODULE__{} = rule, enabled) when is_boolean(enabled), do: %{rule | simple_view: enabled}

  def foureyes(%__MODULE__{} = rule, enabled) when is_boolean(enabled), do: %{rule | foureyes: enabled}

  @doc """
  Convert a `Rule` struct into the nested map format expected by the Guardsix API.
  """
  def to_payload(%__MODULE__{} = rule) do
    reject_nil(%{
      name: rule.name,
      description: rule.description,
      search_params: build_search_params(rule),
      incident_condition: %{
        condition_option: rule.threshold_option,
        condition_value: rule.threshold_value,
        risk: rule.risk_level,
        aggregate: rule.aggregation_type
      },
      taxonomy: %{
        attack_tag_hashes: rule.mitre_tags,
        logsources: rule.log_sources,
        metadata: build_metadata(rule.metadata)
      },
      incident_ownership: %{assignee: rule.assignee, visible_to_usergroups: rule.user_groups},
      incident_display_data: %{
        apply_jinja_template: rule.apply_jinja_template,
        simple_view: rule.simple_view,
        jinja_template: rule.jinja_template
      },
      foureyes: %{original_data: rule.foureyes}
    })
  end

  defp build_search_params(rule) do
    %{
      query: rule.query,
      repos: rule.repos,
      limit: rule.limit,
      flush_on_trigger: rule.flush_on_trigger,
      search_interval_minute: rule.search_interval,
      delay_interval_minute: rule.delay_interval,
      throttling_enabled: rule.throttling_enabled,
      throttling_field: rule.throttling_field,
      throttling_time_range: rule.throttling_time_range,
      timerange_day: rule.time_range_day,
      timerange_hour: rule.time_range_hour,
      timerange_minute: rule.time_range_minute
    }
  end

  # Doesn't reject empty maps on purpose because their parents can be mandatory
  defp reject_nil(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_map(v) -> {k, reject_nil(v)}
      pair -> pair
    end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp build_metadata(meta) when map_size(meta) == 0, do: nil
  defp build_metadata(meta), do: Enum.map(meta, fn {field, value} -> %{field: field, value: value} end)
end
