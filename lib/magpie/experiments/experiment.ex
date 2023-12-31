defmodule Magpie.Experiments.Experiment do
  @moduledoc """
  An Experiment corresponds to an experiment that the author plans to run. Each ExperimentResult and each ExperimentStatus must belong to an Experiment.
  """
  use MagpieWeb, :model

  schema "experiments" do
    field :name, :string, null: false
    field :author, :string, null: false

    # A randomly generated API token which the frontend should provide when interacting with the backend
    field :api_token, :string, null: false

    # Note that the type :text is actually used for Postgres (specified in the migration file). It may not be valid for other databases. The description is potentially longer than varchar(255) limited by the default :string.
    field :description, :string
    field :active, :boolean, default: true, null: false
    field :dynamic_retrieval_keys, {:array, :string}

    field :is_dynamic, :boolean, default: false, null: false
    field :is_interactive, :boolean, default: false, null: false

    # For dynamic experiments.
    field :num_variants, :integer, null: true, default: 1
    field :num_chains, :integer, null: true, default: 1
    field :num_generations, :integer, null: true, default: 1

    # For interactive experiments.
    field :num_players, :integer, null: true, default: 1

    # Accumulation of columns contained in each result JSON submission.
    field :experiment_result_columns, {:array, :string}

    has_many(:experiment_results, Magpie.Experiments.ExperimentResult, on_delete: :delete_all)
    has_many(:experiment_statuses, Magpie.Experiments.ExperimentStatus, on_delete: :delete_all)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [
      :name,
      :author,
      :description,
      :active,
      :dynamic_retrieval_keys,
      :experiment_result_columns,
      :num_variants,
      :num_chains,
      :num_generations,
      :num_players,
      :is_dynamic,
      :is_interactive
    ])
    |> validate_required([:name, :author])
    |> validate_dynamic_experiment_requirements()
  end

  # If the experiment is dynamic, those three numbers must be present.
  # If the experiment is not dynamic, all of them must be absent, otherwise the user has made an error.
  # This is still a bit ugly. Can we do it better?
  # validate_change/3 is only applicable to one single field.
  # A cleaner way would be to create a completely separate model for dynamic experiments, instead of containing everything within one model.
  # For now let's first continue with this I guess.
  defp validate_dynamic_experiment_requirements(changeset) do
    if Ecto.Changeset.get_field(changeset, :is_dynamic) ||
         Ecto.Changeset.get_field(changeset, :is_interactive) do
      changeset
      |> validate_required([:num_variants, :num_chains, :num_generations, :num_players])
      |> validate_number(:num_variants, greater_than: 0)
      |> validate_number(:num_chains, greater_than: 0)
      |> validate_number(:num_generations, greater_than: 0)
      |> validate_number(:num_players, greater_than: 0)
    else
      if Ecto.Changeset.get_change(changeset, :num_variants) ||
           Ecto.Changeset.get_change(changeset, :num_chains) ||
           Ecto.Changeset.get_change(changeset, :num_generations) ||
           Ecto.Changeset.get_change(changeset, :num_players) do
        changeset
        |> add_error(
          :is_dynamic,
          "The num_variant, num_chains, num_generations, num_players attributes are only for dynamic experiments!"
        )
      else
        changeset
      end
    end
  end
end
