from __future__ import annotations

from pathlib import Path

from sf_repo_ai.parsers.parse_apex import parse_apex_file


def test_apex_parser_v2_extracts_rw_and_stats(tmp_path: Path) -> None:
    cls = tmp_path / "MyHandler.cls"
    cls.write_text(
        """
public with sharing class MyHandler {
    public static void run(Id accountId) {
        Account a = [SELECT Id, Name, Status__c FROM Account WHERE Id = :accountId LIMIT 1];
        a.Status__c = 'Updated';
        update a;
        String soql = 'SELECT Id FROM Account';
        List<SObject> rows = Database.query(soql);
    }
}
""".strip()
        + "\n",
        encoding="utf-8",
    )

    data = parse_apex_file(cls, "classes/MyHandler.cls", "APEX")
    stats = data["class_stats"]
    assert stats["class_name"] == "MyHandler"
    assert stats["loc"] > 0
    assert stats["soql_count"] >= 1
    assert stats["dml_count"] >= 1
    assert stats["has_dynamic_soql"] == 1

    rw = data["apex_rw"]
    assert any(r["rw"] == "read" and r.get("field_full_name") == "Account.Name" for r in rw)
    assert any(r["rw"] == "write" and r.get("field_full_name") == "Account.Status__c" for r in rw)
    assert any(r["rw"] == "dml" and r.get("sobject_type") == "Account" for r in rw)
