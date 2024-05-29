// Runs 14 iterations of PageRank over the OpenAIRE beginners citation graph.
//
// table: OpenAIRE beginners v1 Cites, oid 1011
// vertices: 2863498
// edges: 174058
// Dimensions of vectors and

module {
    // out degree
    %out_degree = exec.alloc_vector size=2863498 <!phys.data<si64, i64>>

    %0 = exec.alloc_rel <!phys.data<ui64, i64>>
    %read0 = exec.lean_read_all_edges
        1011
        -> %0 : <!phys.data<ui64, i64>>
        edge_offset_idx=NO_SLOT_INDEX
        base_vertex_idx=0
        column_idx=[NO_SLOT_INDEX]

    %1 = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<si64, i64>>
    exec.eval_expr
        %0 : <!phys.data<ui64, i64>>
        -> %1 : <!phys.data<ui64, i64>, !phys.data<si64, i64>> {
        ^bb0(%arg:!phys.tuple<!phys.data<ui64, i64> [0->0]>):
            %c1 = phys.constant !phys.data<si64, i64>(1)
            phys.eval_expr.return %c1 : !phys.data<si64, i64>
        }

    %accum_degree = exec.vector_write
        %1 : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        -> %out_degree : <!phys.data<si64, i64>>
        index=0
        value=1 ADD

    // read back out degree
    %2 = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<si64, i64>>
    %3 = exec.vector_read_all
        %out_degree : <!phys.data<si64, i64>>
        -> %2 : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        index=0
        value=1
    exec.block %accum_degree blocks %3

    // add damping
    %4 = exec.alloc_rel <
        !phys.data<ui64, i64>,
        !phys.data<si64, i64>,
        !phys.data<f64, f64>>
    exec.eval_expr
        %2 : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        -> %4 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<f64, f64>>
        {
        ^bb0(%arg:!phys.tuple<!phys.data<ui64, i64>, !phys.data<si64, i64> [0->0, 1->1]>):
            %deg = phys.slot 1 %arg : !phys.tuple<!phys.data<ui64, i64>, !phys.data<si64, i64> [0->0, 1->1]> -> !phys.data<si64, i64>
            %degf = phys.cast %deg : !phys.data<si64, i64> -> !phys.data<f64, f64>
            %damping = phys.constant !phys.data<f64, f64>(0.85)
            %damped = phys.div %degf, %damping : !phys.data<f64, f64>
            phys.eval_expr.return %damped : !phys.data<f64, f64>
        }

    // Write back damped out degree
    %d = exec.alloc_vector size=2863498 <!phys.data<f64, f64>>
    %d_write = exec.vector_write
        %4 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<f64, f64>>
        -> %d : <!phys.data<f64, f64>>
        index=0
        value=2 REPLACE

    // sinks
    %5 = exec.alloc_rel <
        !phys.data<ui64, i64>,
        !phys.data<si64, i64>,
        !phys.data<i1, i8>>
    // Find vertices with out degree 0
    exec.eval_expr
        %2 : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        -> %5 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<i1, i8>>
        {
        ^bb0(%arg:!phys.tuple<!phys.data<ui64, i64>, !phys.data<si64, i64> [0->0, 1->1]>):
            %deg = phys.slot 1 %arg : !phys.tuple<!phys.data<ui64, i64>, !phys.data<si64, i64> [0->0, 1->1]> -> !phys.data<si64, i64>
            %c0 = phys.constant !phys.data<si64, i64>(0)
            %cmp = phys.cmp EQ %deg %c0 : !phys.data<si64, i64>
            phys.eval_expr.return %cmp : !phys.data<i1, i8>
        }
    %6 = exec.alloc_rel <
        !phys.data<ui64, i64>,
        !phys.data<si64, i64>,
        !phys.data<i1, i8>,
        !phys.sel_idx>
    exec.filter
        %5 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<i1, i8>>
        -> %6 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<i1, i8>,
            !phys.sel_idx>
        2
    %sinks = exec.alloc_ht initial_capacity=64 <!phys.data<ui64, i64>> -> <!phys.data<si64, i64>>
    %sinks_build = exec.aggregate_build_grouped
        %6 : <
            !phys.data<ui64, i64>,
            !phys.data<si64, i64>,
            !phys.data<i1, i8>,
            !phys.sel_idx>
        group_by=[0]
        aggregators=[#phys<count output=1>]
        -> %sinks : <!phys.data<ui64, i64>> -> <!phys.data<si64, i64>>

    // initial PR scores
    %7 = exec.alloc_rel <!phys.data<ui64, i64>>
    exec.generate_range 0:2863498 -> %7 : <!phys.data<ui64, i64>> output_slot=0
    %8 = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<f64, f64>>
    exec.eval_expr
        %7 : <!phys.data<ui64, i64>>
        -> %8 : <!phys.data<ui64, i64>, !phys.data<f64, f64>> {
        ^bb0(%arg:!phys.tuple<!phys.data<ui64, i64> [0->0]>):
            // 1.0 / n
            %init = phys.constant !phys.data<f64, f64>(0.00000034922322278556)
            phys.eval_expr.return %init : !phys.data<f64, f64>
        }
    %pr = exec.alloc_vector size=2863498 <!phys.data<f64, f64>>
    %new_pr = exec.alloc_vector size=2863498 <!phys.data<f64, f64>>
    %init_fill = exec.vector_write
        %8 : <!phys.data<ui64, i64>, !phys.data<f64, f64>>
        -> %pr : <!phys.data<f64, f64>>
        index=0
        value=1 REPLACE

    %loop_counter = exec.alloc_ht initial_capacity=1 <!phys.data<si64, i64>> -> <!phys.data<si64, i64>>

    // BEGIN loop

    // redistributed from sinks
    // get all sinks
    %sinks_rel = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<si64, i64>>
    %sinks_output = exec.aggregate_output_grouped
        %sinks : <!phys.data<ui64, i64>> -> <!phys.data<si64, i64>>
        -> %sinks_rel : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        build_op=%sinks_build
    exec.block %sinks_build blocks %sinks_output
    // get PR per sink
    %sinks_pr = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<si64, i64>, !phys.data<f64, f64>>
    %label_read = exec.vector_read
        %sinks_rel : <!phys.data<ui64, i64>, !phys.data<si64, i64>>
        %pr : <!phys.data<f64, f64>>
        -> %sinks_pr : <!phys.data<ui64, i64>, !phys.data<si64, i64>, !phys.data<f64, f64>>
        index=0
        value=2
    exec.block %init_fill blocks %label_read
    // aggregate PR of all sinks
    %sinks_pr_agg = exec.aggregate_build
        %sinks_pr : <!phys.data<ui64, i64>, !phys.data<si64, i64>, !phys.data<f64, f64>>
        aggregators=[#phys<monoid 0 SUM = 2>]
    %sinks_pr_agg_rel = exec.alloc_rel <!phys.data<f64,f64>>
    %sinks_pr_output = exec.aggregate_output
        %sinks_pr_agg
        -> %sinks_pr_agg_rel : <!phys.data<f64,f64>>
    exec.block %sinks_pr_agg blocks %sinks_pr_output

    // teleport + redist
    %teleport_redist = exec.alloc_rel <!phys.data<f64, f64>, !phys.data<f64, f64>>
    %teleport_redist_eval = exec.eval_expr
        %sinks_pr_agg_rel : <!phys.data<f64,f64>>
        -> %teleport_redist : <!phys.data<f64, f64>, !phys.data<f64, f64>> {
        ^bb0(%arg:!phys.tuple<!phys.data<f64, f64> [0->0]>):
            // teleport + redist
            // teleport = (1 - damping) / n
            %teleport = phys.constant !phys.data<f64, f64>(0.00000005238348341783)
            %sinks_pr_v = phys.slot 0 %arg :  !phys.tuple<!phys.data<f64, f64> [0->0]> -> !phys.data<f64, f64>
            // damping / n
            %redist_factor = phys.constant !phys.data<f64, f64>(0.00000029683973936772)
            %redist = phys.mul %redist_factor, %sinks_pr_v : !phys.data<f64, f64>
            %sum = phys.add %teleport, %redist : !phys.data<f64, f64>
            phys.eval_expr.return %sum : !phys.data<f64, f64>
        }
    // Broadcast to all positions in the vector
    %pr_range = exec.alloc_rel <!phys.data<ui64, i64>>
    %pr_range_gen = exec.generate_range 0:2863498
        -> %pr_range : <!phys.data<ui64, i64>>
        output_slot=0
    %teleport_redist_all = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<f64, f64>>
    %teleport_redist_join = exec.nested_loop_join
        %pr_range : <!phys.data<ui64, i64>>,
        %teleport_redist : <!phys.data<f64, f64>, !phys.data<f64, f64>>
        -> %teleport_redist_all : <!phys.data<ui64, i64>, !phys.data<f64, f64>>
        [0 rhs=false, 1 rhs=true]
    // Write to vector
    %teleport_redist_write = exec.vector_write
        %teleport_redist_all : <!phys.data<ui64, i64>, !phys.data<f64, f64>>
        -> %new_pr : <!phys.data<f64, f64>>
        index=0
        value=1 REPLACE

    // importance
    %edges = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<ui64, i64>>
    %edges_read = exec.lean_read_all_edges
        1011
        -> %edges : <!phys.data<ui64, i64>, !phys.data<ui64, i64>>
        edge_offset_idx=NO_SLOT_INDEX
        base_vertex_idx=0
        column_idx=[1, NO_SLOT_INDEX]
    // HACK: avoid races in edge reader
    exec.block %read0 blocks %edges_read
    %edges_pr = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<ui64, i64>, !phys.data<f64, f64>>
    %edges_pr_read = exec.vector_read
        %edges : <!phys.data<ui64, i64>, !phys.data<ui64, i64>>
        %pr : <!phys.data<f64, f64>>
        -> %edges_pr : <!phys.data<ui64, i64>, !phys.data<ui64, i64>, !phys.data<f64, f64>>
        index=0
        value=2
    exec.block %init_fill blocks %edges_pr_read
    %edges_pr_d = exec.alloc_rel <
        !phys.data<ui64, i64>,
        !phys.data<ui64, i64>,
        !phys.data<f64, f64>,
        !phys.data<f64, f64>>
    %edges_d_read = exec.vector_read
        %edges_pr : <!phys.data<ui64, i64>, !phys.data<ui64, i64>, !phys.data<f64, f64>>
        %d : <!phys.data<f64, f64>>
        -> %edges_pr_d : <
            !phys.data<ui64, i64>,
            !phys.data<ui64, i64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>>
        index=0
        value=3
    exec.block %d_write blocks %edges_d_read

    %new_pr_in = exec.alloc_rel <
        !phys.data<ui64, i64>,
        !phys.data<ui64, i64>,
        !phys.data<f64, f64>,
        !phys.data<f64, f64>,
        !phys.data<f64, f64>>
    %new_pr_eval = exec.eval_expr
        %edges_pr_d : <
            !phys.data<ui64, i64>,
            !phys.data<ui64, i64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>>
        -> %new_pr_in : <
            !phys.data<ui64, i64>,
            !phys.data<ui64, i64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>>
        {
        ^bb0(%arg:!phys.tuple<
            !phys.data<ui64, i64>,
            !phys.data<ui64, i64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>
            [0->0]>):
            %pr_v = phys.slot
                2
                %arg : !phys.tuple<
                    !phys.data<ui64, i64>,
                    !phys.data<ui64, i64>,
                    !phys.data<f64, f64>,
                    !phys.data<f64, f64>
                    [0->0]>
                -> !phys.data<f64, f64>
            %d_v = phys.slot
                3
                %arg : !phys.tuple<
                    !phys.data<ui64, i64>,
                    !phys.data<ui64, i64>,
                    !phys.data<f64, f64>,
                    !phys.data<f64, f64>
                    [0->0]>
                -> !phys.data<f64, f64>
            %res = phys.div %pr_v, %d_v : !phys.data<f64, f64>
            phys.eval_expr.return %res : !phys.data<f64, f64>
        }
    %new_pr_write = exec.vector_write
        %new_pr_in : <
            !phys.data<ui64, i64>,
            !phys.data<ui64, i64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>,
            !phys.data<f64, f64>>
        -> %new_pr : <!phys.data<f64, f64>>
        index=1
        value=4 ADD
    exec.block %teleport_redist_write blocks %new_pr_write

    %pr_swap = exec.vector_swap %new_pr %pr : <!phys.data<f64, f64>>
    exec.block %new_pr_write blocks %pr_swap

    // Bound the number of iterations
    %one = exec.alloc_rel <!phys.data<si64, i64>>
    %one_read = exec.read_constant_table
        %one : <!phys.data<si64, i64>>
        rows=1
        [#phys<constant_column !phys.data<si64, i64>(1)>]
    %one_write = exec.aggregate_build_grouped
        %one : <!phys.data<si64, i64>>
        group_by=[0]
        aggregators=[#phys<count output=1>]
        -> %loop_counter : <!phys.data<si64, i64>> -> <!phys.data<si64, i64>>
    %counter_rel = exec.alloc_rel <!phys.data<si64, i64>, !phys.data<si64, i64>>
    %counter_read = exec.aggregate_output_grouped
        %loop_counter : <!phys.data<si64, i64>> -> <!phys.data<si64, i64>>
        -> %counter_rel : <!phys.data<si64, i64>, !phys.data<si64, i64>>
        build_op=%one_write
    exec.block %one_write blocks %counter_read

    %counter_cond_rel = exec.alloc_rel <!phys.data<si64, i64>, !phys.data<si64, i64>, !phys.data<i1, i8>>
    %counter_cond_eval = exec.eval_expr
        %counter_rel : <!phys.data<si64, i64>, !phys.data<si64, i64>>
        -> %counter_cond_rel : <!phys.data<si64, i64>, !phys.data<si64, i64>, !phys.data<i1, i8>> {
        ^bb0(%arg:!phys.tuple<!phys.data<si64, i64>, !phys.data<si64, i64> [0->0]>):
            %cnt = phys.slot 1 %arg : !phys.tuple<!phys.data<si64, i64>, !phys.data<si64, i64> [0->0]> -> !phys.data<si64, i64>
            %c14 = phys.constant !phys.data<si64, i64>(14)
            %cnd = phys.cmp EQ %cnt %c14 : !phys.data<si64, i64>
            phys.eval_expr.return %cnd : !phys.data<i1, i8>
        }

    // END loop

    %loop = exec.loop
        %counter_cond_rel : <!phys.data<si64, i64>, !phys.data<si64, i64>, !phys.data<i1, i8>>
        break_slot=2
        reset=[
            %sinks_rel,
            %sinks_output,
            %sinks_pr,
            %label_read,
            %sinks_pr_agg,
            %sinks_pr_agg_rel,
            %sinks_pr_output,
            %teleport_redist,
            %teleport_redist_eval,
            %pr_range,
            %pr_range_gen,
            %teleport_redist_all,
            %teleport_redist_join,
            %teleport_redist_write,
            %edges,
            %edges_read,
            %edges_pr,
            %edges_pr_read,
            %edges_pr_d,
            %edges_d_read,
            %new_pr_in,
            %new_pr_eval,
            %new_pr_write,
            %pr_swap,
            %one,
            %one_read,
            %one_write,
            %counter_rel,
            %counter_read,
            %counter_cond_rel,
            %counter_cond_eval
        ]
            : !exec.relation<!phys.data<ui64, i64>, !phys.data<si64, i64>> // sinks_rel
            , !exec.operator_idx // sinks_output
            , !exec.relation<!phys.data<ui64, i64>, !phys.data<si64, i64>, !phys.data<f64, f64>> // sinks_pr
            , !exec.operator_idx // label_read
            , !exec.operator_idx // sinks_pr_agg
            , !exec.relation<!phys.data<f64,f64>> // sinks_pr_agg_rel
            , !exec.operator_idx // sinks_pr_output
            , !exec.relation<!phys.data<f64, f64>, !phys.data<f64, f64>> // teleport_redist
            , !exec.operator_idx // teleport_redist_eval
            , !exec.relation<!phys.data<ui64, i64>> // pr_range
            , !exec.operator_idx // pr_range_gen
            , !exec.relation<!phys.data<ui64, i64>, !phys.data<f64, f64>> // teleport_redist_all
            , !exec.operator_idx // teleport_redist_join
            , !exec.operator_idx // teleport_redist_write
            , !exec.relation<!phys.data<ui64, i64>, !phys.data<ui64, i64>> // edges
            , !exec.operator_idx // edges_read
            , !exec.relation<!phys.data<ui64, i64>, !phys.data<ui64, i64>, !phys.data<f64, f64>> // edges_pr
            , !exec.operator_idx // edges_pr_read
            , !exec.relation<
                !phys.data<ui64, i64>,
                !phys.data<ui64, i64>,
                !phys.data<f64, f64>,
                !phys.data<f64, f64>> // edges_pr_d
            , !exec.operator_idx // edges_d_read
            , !exec.relation<
                !phys.data<ui64, i64>,
                !phys.data<ui64, i64>,
                !phys.data<f64, f64>,
                !phys.data<f64, f64>,
                !phys.data<f64, f64>> // new_pr_in
            , !exec.operator_idx // new_pr_eval
            , !exec.operator_idx // new_pr_write
            , !exec.operator_idx // pr_swap
            , !exec.relation<!phys.data<si64, i64>> // one
            , !exec.operator_idx // one_read
            , !exec.operator_idx // one_write
            , !exec.relation<!phys.data<si64, i64>, !phys.data<si64, i64>> // counter_rel
            , !exec.operator_idx // counter_read
            , !exec.relation<!phys.data<si64, i64>, !phys.data<si64, i64>, !phys.data<i1, i8>> // counter_cond_rel
            , !exec.operator_idx // counter_cond_eval
    exec.block %pr_swap blocks %loop

    // read final scores.
    %final_out = exec.alloc_rel <!phys.data<ui64, i64>, !phys.data<f64, f64>>
    %final_read = exec.vector_read_all
        %pr : <!phys.data<f64, f64>>
        -> %final_out : <!phys.data<ui64, i64>, !phys.data<f64, f64>>
        index=0
        value=1
    exec.block %loop blocks %final_read

    // Query output
    exec.query_output
        %final_out : <!phys.data<ui64, i64>, !phys.data<f64, f64>>
        {
            vertex = #phys<slot_idx 0>,
            score = #phys<slot_idx 1>
        }
}
