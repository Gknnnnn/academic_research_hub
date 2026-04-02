from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, model_validator


class StageArtifacts(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    json_path: str | None = Field(default=None, alias="json")
    markdown: str | None = None


class Stage045Payload(BaseModel):
    artifacts: StageArtifacts = Field(default_factory=StageArtifacts)
    priority_repairs: list[str] = Field(default_factory=list)
    stage_05_instruction: str | None = None
    red_flag_count: int = 0


class AuditLayer(BaseModel):
    name: str
    layer: str


class WatchtowerSignal(BaseModel):
    theme: str
    score: int


class Stage07Payload(BaseModel):
    artifacts: StageArtifacts = Field(default_factory=StageArtifacts)
    project: str | None = None
    priority_failures: list[str] = Field(default_factory=list)
    active_audit_layers: list[AuditLayer] = Field(default_factory=list)
    meta_prompt_patch: str | None = None
    promotion_rule: str | None = None
    next_hypotheses: list[str] = Field(default_factory=list)
    signals: list[WatchtowerSignal] = Field(default_factory=list)


class PromptInjection(BaseModel):
    trigger: str
    skill_key: str
    instruction: str


class Stage11Payload(BaseModel):
    artifacts: StageArtifacts = Field(default_factory=StageArtifacts)
    project_type: str | None = None
    risk_gaps: list[str] = Field(default_factory=list)
    selected_injections: list[PromptInjection] = Field(default_factory=list)
    reviewer_checklist: list[str] = Field(default_factory=list)
    style_patterns: list[str] = Field(default_factory=list)
    prompt_text: str | None = None


class IntegrityArtifacts(BaseModel):
    json_path: str | None = Field(default=None, alias="json")
    markdown: str | None = None


class Stage08Payload(BaseModel):
    returncode: int = 0
    stdout: str = ""
    stderr: str = ""
    artifacts: IntegrityArtifacts = Field(default_factory=IntegrityArtifacts)


class PipelineManifest(BaseModel):
    stage_04_5: Stage045Payload | None = None
    stage_07: Stage07Payload | None = None
    stage_08: Stage08Payload | None = None
    stage_11: Stage11Payload | None = None


class ReportGenerateRequest(BaseModel):
    manifest: PipelineManifest | None = None
    stage_04_5: Stage045Payload | None = None
    stage_07: Stage07Payload | None = None
    stage_11: Stage11Payload | None = None

    @model_validator(mode="after")
    def sync_legacy_fields(self) -> "ReportGenerateRequest":
        if self.manifest is None:
            self.manifest = PipelineManifest(
                stage_04_5=self.stage_04_5,
                stage_07=self.stage_07,
                stage_11=self.stage_11,
            )
        else:
            if self.stage_04_5 is None:
                self.stage_04_5 = self.manifest.stage_04_5
            if self.stage_07 is None:
                self.stage_07 = self.manifest.stage_07
            if self.stage_11 is None:
                self.stage_11 = self.manifest.stage_11
        return self


def build_stage_045_payload(report: dict[str, Any]) -> Stage045Payload:
    return Stage045Payload(
        artifacts=StageArtifacts(**(report.get("artifacts") or {})),
        priority_repairs=list(report["synthesis_mediator"]["priority_repairs"]),
        stage_05_instruction=report["synthesis_mediator"]["stage_05_instruction"],
        red_flag_count=int(report["data_auditor"]["red_flag_count"]),
    )


def build_stage_07_payload(report: dict[str, Any]) -> Stage07Payload:
    return Stage07Payload(
        artifacts=StageArtifacts(**(report.get("artifacts") or {})),
        project=report.get("project", {}).get("project_name"),
        priority_failures=list(report.get("meta_directive", {}).get("priority_failures", [])),
        active_audit_layers=[
            AuditLayer(name=item["name"], layer=item["layer"])
            for item in report.get("meta_directive", {}).get("active_audit_layers", [])
        ],
        meta_prompt_patch=report.get("meta_directive", {}).get("meta_prompt_patch"),
        promotion_rule=report.get("meta_directive", {}).get("promotion_rule"),
        next_hypotheses=list(report.get("watchtower", {}).get("next_hypotheses", [])),
        signals=[
            WatchtowerSignal(theme=item["theme"], score=int(item["score"]))
            for item in report.get("watchtower", {}).get("signals", [])
        ],
    )


def build_stage_11_payload(report: dict[str, Any]) -> Stage11Payload:
    dynamic = report.get("dynamic_prompt_context", {})
    return Stage11Payload(
        artifacts=StageArtifacts(
            **{
                "json": report.get("artifacts", {}).get("json"),
                "markdown": report.get("artifacts", {}).get("prompt_context"),
            }
        ),
        project_type=dynamic.get("project_type"),
        risk_gaps=list(dynamic.get("risk_gaps", [])),
        selected_injections=[
            PromptInjection(
                trigger=item["trigger"],
                skill_key=item["skill_key"],
                instruction=item["instruction"],
            )
            for item in dynamic.get("selected_injections", [])
        ],
        reviewer_checklist=list(dynamic.get("reviewer_checklist", [])),
        style_patterns=list(dynamic.get("style_patterns", [])),
        prompt_text=dynamic.get("prompt_text"),
    )


def build_stage_08_payload(result: dict[str, Any]) -> Stage08Payload:
    return Stage08Payload(
        returncode=int(result.get("returncode", 1)),
        stdout=str(result.get("stdout", "")),
        stderr=str(result.get("stderr", "")),
        artifacts=IntegrityArtifacts(
            **{
                "json": result.get("json"),
                "markdown": result.get("markdown"),
            }
        ),
    )


def build_pipeline_manifest(
    *,
    socratic_report: dict[str, Any] | None = None,
    meta_report: dict[str, Any] | None = None,
    integrity_result: dict[str, Any] | None = None,
    evolution_report: dict[str, Any] | None = None,
) -> PipelineManifest:
    return PipelineManifest(
        stage_04_5=build_stage_045_payload(socratic_report) if socratic_report else None,
        stage_07=build_stage_07_payload(meta_report) if meta_report else None,
        stage_08=build_stage_08_payload(integrity_result) if integrity_result else None,
        stage_11=build_stage_11_payload(evolution_report) if evolution_report else None,
    )
