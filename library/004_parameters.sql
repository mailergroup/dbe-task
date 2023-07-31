alter system set work_mem = 8192;
alter system set max_worker_processes = 16;
alter system set max_parallel_workers_per_gather = 4;
alter system set max_parallel_maintenance_workers = 8;
alter system set wal_buffers = 16384;