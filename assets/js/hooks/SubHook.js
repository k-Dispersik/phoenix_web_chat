const ModalHook = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      const modal = document.querySelector("#redemption_form");

      if (modal) {
        modal.classList.remove("hidden");

        modal.classList.add("fade-in");
      }

      window.scrollTo({
        top: document.body.scrollHeight,
        behavior: "smooth"
      });
    });
  }
};

export default ModalHook;
