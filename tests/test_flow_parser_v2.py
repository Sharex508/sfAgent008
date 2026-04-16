from __future__ import annotations

from pathlib import Path

from sf_repo_ai.parsers.parse_flows import parse_flow_meta


def _write_flow(tmp_path: Path, name: str, body: str) -> Path:
    path = tmp_path / f"{name}.flow-meta.xml"
    path.write_text(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<Flow xmlns=\"http://soap.sforce.com/2006/04/metadata\">\n"
        f"{body}\n"
        "</Flow>\n",
        encoding="utf-8",
    )
    return path


def test_assignment_without_dml_is_not_true_write(tmp_path: Path) -> None:
    flow = _write_flow(
        tmp_path,
        "AssignOnly",
        """
    <start>
      <object>Account</object>
      <triggerType>RecordAfterSave</triggerType>
    </start>
    <assignments>
      <name>SetName</name>
      <assignmentItems>
        <assignToReference>$Record.Name</assignToReference>
        <operator>Assign</operator>
        <value><stringValue>X</stringValue></value>
      </assignmentItems>
    </assignments>
    """,
    )
    data = parse_flow_meta(flow, flow.name)
    assert not [x for x in data["flow_true_writes"] if x["write_kind"] == "field_write"]
    assert data["writes"] == []


def test_record_update_without_field_assignment_counts_object_update_only(tmp_path: Path) -> None:
    flow = _write_flow(
        tmp_path,
        "ObjectOnlyUpdate",
        """
    <start>
      <object>Account</object>
      <triggerType>RecordAfterSave</triggerType>
    </start>
    <recordUpdates>
      <name>UpdateRecord</name>
      <inputReference>$Record</inputReference>
    </recordUpdates>
    """,
    )
    data = parse_flow_meta(flow, flow.name)
    writes = data["flow_true_writes"]
    record_rows = [x for x in writes if x["write_kind"] == "record_write" and x.get("sobject_type") == "Account"]
    field_rows = [x for x in writes if x["write_kind"] == "field_write"]
    assert record_rows
    assert not field_rows


def test_collection_update_with_assignment_is_true_field_write(tmp_path: Path) -> None:
    flow = _write_flow(
        tmp_path,
        "CollectionWrite",
        """
    <variables>
      <name>LoopVar</name>
      <dataType>SObject</dataType>
      <isCollection>false</isCollection>
      <objectType>Account</objectType>
    </variables>
    <variables>
      <name>StoreAll</name>
      <dataType>SObject</dataType>
      <isCollection>true</isCollection>
      <objectType>Account</objectType>
    </variables>
    <assignments>
      <name>SetLoopVar</name>
      <assignmentItems>
        <assignToReference>LoopVar.Name</assignToReference>
        <operator>Assign</operator>
        <value><stringValue>Updated</stringValue></value>
      </assignmentItems>
      <assignmentItems>
        <assignToReference>StoreAll</assignToReference>
        <operator>Add</operator>
        <value><elementReference>LoopVar</elementReference></value>
      </assignmentItems>
    </assignments>
    <recordUpdates>
      <name>PersistAll</name>
      <inputReference>StoreAll</inputReference>
    </recordUpdates>
    """,
    )
    data = parse_flow_meta(flow, flow.name)
    field_rows = [
        x for x in data["flow_true_writes"] if x["write_kind"] == "field_write" and x.get("field_full_name") == "Account.Name"
    ]
    assert field_rows
