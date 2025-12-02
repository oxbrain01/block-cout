defmodule BlockScoutWeb.RecentTransactionsController do
  use BlockScoutWeb, :controller

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{DenormalizationHelper, Hash}
  alias Phoenix.View

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def index(conn, _params) do
    if ajax?(conn) do
      recent_transactions =
        Chain.recent_collated_transactions(
          true,
          DenormalizationHelper.extend_block_necessity(
            [
              necessity_by_association: %{
                [created_contract_address: :names] => :optional,
                [from_address: :names] => :optional,
                [to_address: :names] => :optional,
                [created_contract_address: :smart_contract] => :optional,
                [from_address: :smart_contract] => :optional,
                [to_address: :smart_contract] => :optional
              },
              paging_options: %PagingOptions{page_size: 5}
            ],
            :required
          )
        )
        |> Enum.sort(fn a, b ->
          block_compare = compare_block_numbers(a.block_number, b.block_number)

          case block_compare do
            :gt -> true
            :lt -> false
            :eq ->
              index_compare = compare_indices(a.index, b.index)

              case index_compare do
                :gt -> true
                :lt -> false
                :eq ->
                  DateTime.compare(
                    a.inserted_at || ~U[1970-01-01 00:00:00Z],
                    b.inserted_at || ~U[1970-01-01 00:00:00Z]
                  ) == :gt
              end
          end
        end)

      transactions =
        Enum.map(recent_transactions, fn transaction ->
          %{
            transaction_hash: Hash.to_string(transaction.hash),
            transaction_html:
              View.render_to_string(BlockScoutWeb.TransactionView, "_tile.html",
                transaction: transaction,
                burn_address_hash: @burn_address_hash,
                conn: conn
              )
          }
        end)

      json(conn, %{transactions: transactions})
    else
      unprocessable_entity(conn)
    end
  end

  defp compare_block_numbers(nil, nil), do: :eq
  defp compare_block_numbers(nil, _), do: :lt
  defp compare_block_numbers(_, nil), do: :gt
  defp compare_block_numbers(a, b) when a > b, do: :gt
  defp compare_block_numbers(a, b) when a < b, do: :lt
  defp compare_block_numbers(_, _), do: :eq

  defp compare_indices(nil, nil), do: :eq
  defp compare_indices(nil, _), do: :lt
  defp compare_indices(_, nil), do: :gt
  defp compare_indices(a, b) when a > b, do: :gt
  defp compare_indices(a, b) when a < b, do: :lt
  defp compare_indices(_, _), do: :eq
end
