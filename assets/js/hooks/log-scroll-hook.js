const LogScrollHook = {
  mounted() {
    this.scheduleScroll();
  },
  updated() {
    this.scheduleScroll();
  },
  scheduleScroll() {
    // Schedule the scroll to happen after the next frame to ensure the DOM is updated
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight;
    });
  }
};

export default LogScrollHook;
