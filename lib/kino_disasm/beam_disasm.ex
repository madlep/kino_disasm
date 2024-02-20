defmodule Kino.Disasm.BeamDisasm do
  @type t() :: %__MODULE__{
          mod: module(),
          exports: list(:beam_lib.labeled_entry()),
          attributes: list(:beam_lib.attrib_entry()),
          compile_info: list(:beam_lib.compinfo_entry()),
          functions: list(beam_function())
        }
  defstruct [:mod, :exports, :attributes, :compile_info, :functions]

  @type beam_function() :: {
          :function,
          name :: atom(),
          arity :: byte(),
          entry :: :beam_lib.label(),
          code :: list(:beam_disasm.beam_instr())
        }

  @spec new(module() | (code :: binary())) :: {:ok, t()} | {:error, reason :: binary()}

  def new(mod) when is_atom(mod) do
    case :code.get_object_code(mod) do
      {^mod, beam_binary, _path} -> new(beam_binary)
      :error -> {:error, "couldn't load object code for #{mod}"}
    end
  end

  def new(beam_binary) when is_binary(beam_binary) do
    case :beam_disasm.file(beam_binary) do
      {:beam_file, mod, exports, attributes, compile_info, functions} ->
        {:ok,
         %__MODULE__{
           mod: mod,
           exports: exports,
           attributes: attributes,
           compile_info: compile_info,
           functions: functions
         }}

      error ->
        error
    end
  end
end
