# Sample automation workflow
from ipaf.core.workflow import PentestWorkflow

workflow = PentestWorkflow(
    targets="10.0.2.0/24",
    phases=[
        "recon:subfinder,sublist3r",
        "enum:nmap,masscan,sqlmap",
        "exploit:msf,hydra",
        "report:html,pdf"
    ],
    config="default"
)
workflow.execute()