defmodule Breadcrumbs do
  use X.Component,
    assigns: %{
      :crumbs => list()
    },
    template: ~X"""
    <nav
      :attrs="@attrs"
      aria-label="breadcrumb"
    >
      <ol class="breadcrumb">
        <li
          x-for="item <- crumbs"
          :class=[active: item.active]
          class="breadcrumb-item"
        >
          <span x-if="item.active">
            {{ item.title }}
          </span>
          <RouterLink
            x-else
            :params="item.params"
            :to="item.to"
          >{{ item.title }}</RouterLink>
        </li>
      </ol>
    </nav>
    """
end
