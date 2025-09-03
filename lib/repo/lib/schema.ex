defmodule Repo.Schema do

  defmacro __using__(_) do
    quote generated: true do
      use Ecto.Schema

      import Ecto.Query, only: [from: 2]

      @timestamps_opts inserted_at: :created_at
    end
  end
end
