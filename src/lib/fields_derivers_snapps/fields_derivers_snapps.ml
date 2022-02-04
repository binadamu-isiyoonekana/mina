open Core_kernel

module Derivers = struct
  let derivers () =
    let open Fields_derivers_graphql in
    let graphql_fields =
      ref Graphql_fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let contramap = ref (fun _ -> failwith "unimplemented") in
    let nullable_graphql_fields =
      ref Graphql_fields.Input.T.{ run = (fun () -> failwith "unimplemented") }
    in
    let graphql_fields_accumulator = ref [] in
    let nullable = ref Nullable.Non_null in
    let to_json = ref (fun _ -> failwith "unimplemented") in
    let of_json = ref (fun _ -> failwith "unimplemented") in
    let to_json_accumulator = ref [] in
    let of_json_creator = ref String.Map.empty in
    let map = ref (fun _ -> failwith "unimplemented") in

    object
      method graphql_fields = graphql_fields

      method contramap = contramap

      method nullable_graphql_fields = nullable_graphql_fields

      method graphql_fields_accumulator = graphql_fields_accumulator

      method nullable = nullable

      method to_json = to_json

      method map = map

      method of_json = of_json

      method to_json_accumulator = to_json_accumulator

      method of_json_creator = of_json_creator
    end

  let o () = derivers ()

  module Unified_input = struct
    type 'a t = < .. > as 'a
      constraint 'a = _ Fields_derivers_json.To_yojson.Input.t
      constraint 'a = _ Fields_derivers_json.Of_yojson.Input.t
      constraint 'a = _ Fields_derivers_graphql.Graphql_fields.Input.t
  end

  let yojson obj ?doc ~name ~map ~contramap : 'a Unified_input.t =
    let open Fields_derivers_graphql in
    (obj#graphql_fields :=
       let open Graphql_fields.Schema in
       Graphql_fields.Input.T.
         { run =
             (fun () ->
               scalar name ?doc ~coerce:Yojson.Safe.to_basic |> non_null)
         }) ;

    obj#contramap := contramap ;

    (obj#nullable_graphql_fields :=
       let open Graphql_fields.Schema in
       Graphql_fields.Input.T.
         { run = (fun () -> scalar name ?doc ~coerce:Yojson.Safe.to_basic) }) ;

    obj#to_json := Fn.id ;

    obj#map := map ;

    obj#of_json := Fn.id ;
    obj

  let iso_string obj ~(to_string : 'a -> string) ~(of_string : string -> 'a)
      ~doc ~name =
    yojson obj ~doc ~name
      ~map:(function `String x -> of_string x | _ -> failwith "unsupported")
      ~contramap:(fun uint64 -> `String (to_string uint64))

  let uint64 obj : _ Unified_input.t =
    iso_string obj
      ~doc:"Unsigned 64-bit integer represented as a string in base10"
      ~name:"UInt64" ~to_string:Unsigned.UInt64.to_string
      ~of_string:Unsigned.UInt64.of_string

  let uint32 obj : _ Unified_input.t =
    iso_string obj
      ~doc:"Unsigned 32-bit integer represented as a string in base10"
      ~name:"UInt32" ~to_string:Unsigned.UInt32.to_string
      ~of_string:Unsigned.UInt32.of_string

  let field obj : _ Unified_input.t =
    let module Field = Pickles.Impls.Step.Field.Constant in
    iso_string obj ~name:"Field" ~doc:"String representing an Fp Field element"
      ~to_string:Field.to_string ~of_string:Field.of_string

  let int obj =
    let _a = Fields_derivers_graphql.Graphql_fields.int obj in
    let _b = Fields_derivers_json.To_yojson.int obj in
    Fields_derivers_json.Of_yojson.int obj

  let string obj =
    let _a = Fields_derivers_graphql.Graphql_fields.int obj in
    let _b = Fields_derivers_json.To_yojson.int obj in
    Fields_derivers_json.Of_yojson.int obj

  let option (x : _ Unified_input.t) obj : _ Unified_input.t =
    let _a = Fields_derivers_graphql.Graphql_fields.option x obj in
    let _b = Fields_derivers_json.To_yojson.option x obj in
    Fields_derivers_json.Of_yojson.option x obj

  let list (x : _ Unified_input.t) obj : _ Unified_input.t =
    let _a = Fields_derivers_graphql.Graphql_fields.list x obj in
    let _b = Fields_derivers_json.To_yojson.list x obj in
    Fields_derivers_json.Of_yojson.list x obj

  let iso ~map ~contramap (x : _ Unified_input.t) obj : _ Unified_input.t =
    let _a =
      Fields_derivers_graphql.Graphql_fields.contramap ~f:contramap x obj
    in
    let _b = Fields_derivers_json.To_yojson.contramap ~f:contramap x obj in
    Fields_derivers_json.Of_yojson.map ~f:map x obj

  let add_field (x : _ Unified_input.t) fd acc =
    let _, acc' = Fields_derivers_graphql.Graphql_fields.add_field x fd acc in
    let _, acc'' = Fields_derivers_json.To_yojson.add_field x fd acc' in
    Fields_derivers_json.Of_yojson.add_field x fd acc''

  let ( !. ) x fd acc = add_field (x @@ o ()) fd acc

  let finish ~name ?doc res =
    let _a = Fields_derivers_graphql.Graphql_fields.finish ~name ?doc res in
    let _b = Fields_derivers_json.To_yojson.finish res in
    Fields_derivers_json.Of_yojson.finish res

  let to_json obj x = !(obj#to_json) x

  let of_json obj x = !(obj#of_json) x

  let typ obj =
    !(obj#graphql_fields).Fields_derivers_graphql.Graphql_fields.Input.T.run ()
end

let%test_module "Test" =
  ( module struct
    module Field = Pickles.Impls.Step.Field.Constant

    module Or_ignore_test = struct
      type 'a t = Check of 'a | Ignore [@@deriving compare, sexp, equal]

      let of_option = function None -> Ignore | Some x -> Check x

      let to_option = function Ignore -> None | Check x -> Some x

      let to_yojson a x = [%to_yojson: 'a option] a (to_option x)

      let of_yojson a x = Result.map ~f:of_option ([%of_yojson: 'a option] a x)

      let derived inner init =
        let open Derivers in
        iso ~map:of_option ~contramap:to_option
          ((option @@ inner @@ o ()) (o ()))
          init
    end

    module V = struct
      type t =
        { foo : int
        ; foo1 : Unsigned_extended.UInt64.t
        ; bar : Unsigned_extended.UInt64.t Or_ignore_test.t
        ; baz : Unsigned_extended.UInt32.t list
        }
      [@@deriving compare, sexp, equal, fields, yojson]

      let v =
        { foo = 1
        ; foo1 = Unsigned.UInt64.of_int 10
        ; bar = Or_ignore_test.Check (Unsigned.UInt64.of_int 10)
        ; baz = Unsigned.UInt32.[ of_int 11; of_int 12 ]
        }

      let derivers obj =
        let open Derivers in
        Fields.make_creator obj ~foo:!.int ~foo1:!.uint64
          ~bar:!.(Or_ignore_test.derived uint64)
          ~baz:!.(list @@ uint32 @@ o ())
        |> finish ~name:"V"
    end

    let v1 = V.derivers @@ Derivers.o ()

    let%test_unit "roundtrips json" =
      let open Derivers in
      [%test_eq: V.t]
        (of_json v1 @@ to_json v1 V.v)
        (V.of_yojson (V.to_yojson V.v) |> Result.ok_or_failwith)

    module V2 = struct
      type t = { field : Field.t } [@@deriving compare, sexp, equal, fields]

      let v = { field = Field.of_int 10 }

      let derivers obj =
        let open Derivers in
        Fields.make_creator obj ~field:!.field |> finish ~name:"V2"
    end

    let v2 = V2.derivers @@ Derivers.o ()

    let%test_unit "to_json'" =
      let open Derivers in
      [%test_eq: string]
        (Yojson.Safe.to_string (to_json v2 V2.v))
        {|{"field":"10"}|}

    let%test_unit "roundtrip json'" =
      let open Derivers in
      [%test_eq: V2.t] (of_json v2 (to_json v2 V2.v)) V2.v
  end )
