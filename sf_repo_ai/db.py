from __future__ import annotations

import sqlite3
from pathlib import Path


def connect(sqlite_path: Path) -> sqlite3.Connection:
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(sqlite_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS components (
          id INTEGER PRIMARY KEY,
          type TEXT,
          name TEXT,
          path TEXT UNIQUE,
          hash TEXT
        );

        CREATE TABLE IF NOT EXISTS objects (
          object_name TEXT PRIMARY KEY,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS fields (
          object_name TEXT,
          field_api TEXT,
          full_name TEXT UNIQUE,
          data_type TEXT,
          formula TEXT NULL,
          reference_to TEXT NULL,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS validation_rules (
          object_name TEXT,
          rule_name TEXT,
          active INTEGER,
          error_condition TEXT,
          error_message TEXT,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS flows (
          flow_name TEXT PRIMARY KEY,
          status TEXT NULL,
          trigger_object TEXT NULL,
          trigger_type TEXT NULL,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS flow_field_reads (
          flow_name TEXT,
          full_field_name TEXT,
          path TEXT,
          confidence REAL
        );

        CREATE TABLE IF NOT EXISTS flow_field_writes (
          flow_name TEXT,
          full_field_name TEXT,
          path TEXT,
          confidence REAL
        );

        CREATE TABLE IF NOT EXISTS flow_vars (
          flow_name TEXT,
          var_name TEXT,
          data_type TEXT,
          is_collection INTEGER,
          sobject_type TEXT NULL,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS flow_assignments (
          flow_name TEXT,
          assignment_name TEXT,
          lhs TEXT,
          rhs TEXT,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS flow_dml (
          flow_name TEXT,
          element_name TEXT,
          dml_type TEXT,
          record_var TEXT,
          sobject_type TEXT NULL,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS flow_true_writes (
          flow_name TEXT,
          sobject_type TEXT NULL,
          field_full_name TEXT NULL,
          write_kind TEXT,
          confidence REAL,
          evidence_path TEXT,
          evidence_snippet TEXT NULL,
          source_element TEXT NULL
        );

        CREATE TABLE IF NOT EXISTS apex_endpoints (
          class_name TEXT,
          path TEXT,
          endpoint_value TEXT,
          endpoint_type TEXT,
          line_start INTEGER,
          line_end INTEGER
        );

        CREATE TABLE IF NOT EXISTS apex_class_stats (
          class_name TEXT PRIMARY KEY,
          loc INTEGER,
          soql_count INTEGER,
          dml_count INTEGER,
          has_dynamic_soql INTEGER,
          has_callout INTEGER,
          path TEXT
        );

        CREATE TABLE IF NOT EXISTS apex_rw (
          class_name TEXT,
          sobject_type TEXT NULL,
          field_full_name TEXT NULL,
          rw TEXT,
          confidence REAL,
          path TEXT,
          evidence_snippet TEXT NULL
        );

        CREATE TABLE IF NOT EXISTS "references" (
          ref_type TEXT,
          ref_key TEXT,
          src_type TEXT,
          src_name TEXT,
          src_path TEXT,
          line_start INTEGER NULL,
          line_end INTEGER NULL,
          snippet TEXT NULL,
          confidence REAL
        );

        CREATE TABLE IF NOT EXISTS graph_nodes (
          node_id INTEGER PRIMARY KEY,
          node_type TEXT,
          name TEXT,
          path TEXT NULL,
          extra_json TEXT NULL,
          UNIQUE(node_type, name)
        );

        CREATE TABLE IF NOT EXISTS graph_edges (
          edge_id INTEGER PRIMARY KEY,
          src_node_id INTEGER,
          dst_node_id INTEGER,
          edge_type TEXT,
          confidence REAL,
          evidence_path TEXT NULL,
          evidence_line_start INTEGER NULL,
          evidence_line_end INTEGER NULL,
          evidence_snippet TEXT NULL,
          extra_json TEXT NULL,
          FOREIGN KEY(src_node_id) REFERENCES graph_nodes(node_id),
          FOREIGN KEY(dst_node_id) REFERENCES graph_nodes(node_id)
        );

        CREATE TABLE IF NOT EXISTS meta_files (
          path TEXT PRIMARY KEY,
          folder TEXT,
          file_name TEXT,
          extension TEXT,
          type_guess TEXT,
          api_name TEXT,
          xml_root TEXT NULL,
          active INTEGER NULL,
          sobject TEXT NULL,
          xml_parse_error INTEGER DEFAULT 0,
          file_size INTEGER NULL,
          mtime_ns INTEGER NULL,
          hash TEXT,
          indexed_at TEXT
        );

        CREATE TABLE IF NOT EXISTS meta_refs (
          ref_kind TEXT,
          ref_value TEXT,
          src_path TEXT,
          src_folder TEXT,
          line_no INTEGER,
          snippet TEXT,
          confidence REAL
        );

        CREATE TABLE IF NOT EXISTS metadata_catalog (
          type_key TEXT,
          scope TEXT,
          top_folder TEXT,
          object_child_folder TEXT NULL,
          suffix TEXT,
          count_total INTEGER,
          sample_path TEXT
        );

        CREATE TABLE IF NOT EXISTS approval_processes (
          name TEXT,
          object_name TEXT NULL,
          active INTEGER NULL,
          path TEXT PRIMARY KEY
        );

        CREATE TABLE IF NOT EXISTS sharing_rules (
          name TEXT,
          object_name TEXT,
          rule_type TEXT NULL,
          access_level TEXT NULL,
          active INTEGER NULL,
          path TEXT,
          extra_json TEXT NULL,
          PRIMARY KEY(path, name)
        );

        CREATE TABLE IF NOT EXISTS evidence_cache (
          target_key TEXT PRIMARY KEY,
          depth INT,
          top_n INT,
          json TEXT,
          created_at TEXT,
          input_hash TEXT
        );

        CREATE TABLE IF NOT EXISTS log_captures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          org_alias TEXT,
          user_id TEXT,
          login_url TEXT,
          sf_username TEXT,
          sf_password TEXT,
          sf_token TEXT,
          start_ts TEXT,
          end_ts TEXT,
          filter_text TEXT,
          status TEXT
        );

        CREATE TABLE IF NOT EXISTS log_capture_logs (
          capture_id INTEGER,
          log_id TEXT,
          start_ts TEXT,
          length INTEGER,
          status TEXT,
          error TEXT,
          PRIMARY KEY (capture_id, log_id)
        );

        CREATE INDEX IF NOT EXISTS idx_references_type_key ON "references"(ref_type, ref_key);
        CREATE INDEX IF NOT EXISTS idx_flow_field_writes_name ON flow_field_writes(full_field_name);
        CREATE INDEX IF NOT EXISTS idx_flow_true_writes_field ON flow_true_writes(field_full_name);
        CREATE INDEX IF NOT EXISTS idx_flow_true_writes_object ON flow_true_writes(sobject_type);
        CREATE INDEX IF NOT EXISTS idx_apex_endpoints_value ON apex_endpoints(endpoint_value);
        CREATE INDEX IF NOT EXISTS idx_apex_rw_field ON apex_rw(field_full_name);
        CREATE INDEX IF NOT EXISTS idx_apex_rw_object_rw ON apex_rw(sobject_type, rw);
        CREATE INDEX IF NOT EXISTS idx_apex_rw_class_rw ON apex_rw(class_name, rw);
        CREATE INDEX IF NOT EXISTS idx_edges_src ON graph_edges(src_node_id);
        CREATE INDEX IF NOT EXISTS idx_edges_dst ON graph_edges(dst_node_id);
        CREATE INDEX IF NOT EXISTS idx_edges_type ON graph_edges(edge_type);
        CREATE INDEX IF NOT EXISTS idx_nodes_type_name ON graph_nodes(node_type, name);
        CREATE INDEX IF NOT EXISTS idx_meta_files_folder ON meta_files(folder);
        CREATE INDEX IF NOT EXISTS idx_meta_files_type ON meta_files(type_guess);
        CREATE INDEX IF NOT EXISTS idx_meta_refs_value ON meta_refs(ref_value);
        CREATE INDEX IF NOT EXISTS idx_meta_refs_kind_value ON meta_refs(ref_kind, ref_value);
        CREATE INDEX IF NOT EXISTS idx_meta_refs_src_path ON meta_refs(src_path);
        CREATE INDEX IF NOT EXISTS idx_metadata_catalog_type ON metadata_catalog(type_key);
        CREATE INDEX IF NOT EXISTS idx_metadata_catalog_scope ON metadata_catalog(scope);
        CREATE INDEX IF NOT EXISTS idx_metadata_catalog_folder ON metadata_catalog(top_folder, object_child_folder);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_metadata_catalog_dedup
          ON metadata_catalog(type_key, scope, top_folder, IFNULL(object_child_folder,''), suffix);
        CREATE INDEX IF NOT EXISTS idx_approval_processes_object_active
          ON approval_processes(object_name, active);
        CREATE INDEX IF NOT EXISTS idx_sharing_rules_object_access
          ON sharing_rules(object_name, access_level);
        CREATE INDEX IF NOT EXISTS idx_evidence_cache_input
          ON evidence_cache(input_hash);
        CREATE INDEX IF NOT EXISTS idx_log_captures_org_user
          ON log_captures(org_alias, user_id);
        CREATE INDEX IF NOT EXISTS idx_log_capture_logs_capture
          ON log_capture_logs(capture_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_graph_edge_dedup
          ON graph_edges(src_node_id, dst_node_id, edge_type, IFNULL(evidence_path,''), IFNULL(evidence_line_start,-1), IFNULL(evidence_line_end,-1));
        """
    )
    # Backward-compatible migrations for existing DBs.
    try:
        conn.execute("ALTER TABLE meta_files ADD COLUMN xml_parse_error INTEGER DEFAULT 0")
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute("ALTER TABLE meta_files ADD COLUMN file_size INTEGER")
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute("ALTER TABLE meta_files ADD COLUMN mtime_ns INTEGER")
    except sqlite3.OperationalError:
        pass
    conn.commit()


def get_component_hash(conn: sqlite3.Connection, path: str) -> str | None:
    row = conn.execute("SELECT hash FROM components WHERE path = ?", (path,)).fetchone()
    return row["hash"] if row else None


def get_meta_file_state(conn: sqlite3.Connection, path: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT hash, file_size, mtime_ns FROM meta_files WHERE path = ?",
        (path,),
    ).fetchone()


def upsert_component(conn: sqlite3.Connection, *, comp_type: str, name: str, path: str, sha1: str) -> None:
    conn.execute(
        """
        INSERT INTO components(type, name, path, hash)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(path) DO UPDATE SET
          type=excluded.type,
          name=excluded.name,
          hash=excluded.hash
        """,
        (comp_type, name, path, sha1),
    )


def clear_rows_for_path(conn: sqlite3.Connection, path: str) -> None:
    conn.execute("DELETE FROM objects WHERE path = ?", (path,))
    conn.execute("DELETE FROM fields WHERE path = ?", (path,))
    conn.execute("DELETE FROM validation_rules WHERE path = ?", (path,))
    conn.execute("DELETE FROM flows WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_field_reads WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_field_writes WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_vars WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_assignments WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_dml WHERE path = ?", (path,))
    conn.execute("DELETE FROM flow_true_writes WHERE evidence_path = ?", (path,))
    conn.execute("DELETE FROM apex_endpoints WHERE path = ?", (path,))
    conn.execute("DELETE FROM apex_class_stats WHERE path = ?", (path,))
    conn.execute("DELETE FROM apex_rw WHERE path = ?", (path,))
    conn.execute("DELETE FROM \"references\" WHERE src_path = ?", (path,))
    conn.execute("DELETE FROM meta_files WHERE path = ?", (path,))
    conn.execute("DELETE FROM meta_refs WHERE src_path = ?", (path,))
    conn.execute("DELETE FROM approval_processes WHERE path = ?", (path,))
    conn.execute("DELETE FROM sharing_rules WHERE path = ?", (path,))


def delete_component_path(conn: sqlite3.Connection, path: str) -> None:
    clear_rows_for_path(conn, path)
    conn.execute("DELETE FROM components WHERE path = ?", (path,))


def all_component_paths(conn: sqlite3.Connection) -> set[str]:
    rows = conn.execute("SELECT path FROM components").fetchall()
    return {r["path"] for r in rows}
