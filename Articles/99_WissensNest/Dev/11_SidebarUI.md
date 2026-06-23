# My AI

## Sidebar UI

### Scope for this step

1. Collapse/expand per project — click the project name to toggle its conversation list. Simple _bool_ per project in the sidebar.
2. New Project — a small inline form or modal in the sidebar: type a name, press Enter/confirm, calls a new _POST /projects_ API endpoint.
3. Project CRUD in API — you'll need _IProjectRepository.GetAllAsync()_ wired to a ? endpoint, and a _POST /projects_ endpoint. Both are straightforward given your existing pattern.

### The evolvement of the UI

At this stage I also would like to add the following possibilities:

1. Editing project name;
2. Editing of the particular messages;
3. Soft-Removing of the particular messages;
4. Soft-Removing of the particular conversations;
5. Soft-Removing of the particular project.
