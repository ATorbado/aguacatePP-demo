package com.atorbado.vialidadinvernal;

import com.atorbado.vialidadinvernal.config.EditionSettings;
import com.atorbado.vialidadinvernal.config.RuntimeConfiguration;
import com.atorbado.vialidadinvernal.config.RuntimeConfigurationLoader;
import com.atorbado.vialidadinvernal.delivery.DeliveryRequest;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.io.IOException;
import java.util.List;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

public final class VialidadInvernalApp {
    private VialidadInvernalApp() {
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(VialidadInvernalApp::start);
    }

    private static void start() {
        try {
            EditionSettings settings = EditionSettings.loadBundled();
            RuntimeConfiguration configuration = RuntimeConfigurationLoader.load(settings);
            ApplicationServices services = ApplicationServices.create(configuration);
            showWindow(settings, services);
        } catch (RuntimeException | IOException error) {
            JOptionPane.showMessageDialog(
                    null,
                    error.getMessage(),
                    "Configuración no válida",
                    JOptionPane.ERROR_MESSAGE);
        }
    }

    private static void showWindow(EditionSettings settings, ApplicationServices services) {
        JFrame frame = new JFrame(settings.displayName());
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setMinimumSize(new Dimension(520, 240));

        JPanel content = new JPanel(new BorderLayout(12, 12));
        content.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        content.add(new JLabel("Carpeta de trabajo: " + services.workspace().root()),
                BorderLayout.NORTH);

        JLabel state = new JLabel(
                "Demostración local: crea una vista previa ficticia sin usar la red.");
        content.add(state, BorderLayout.CENTER);

        JButton action = new JButton("Crear vista previa ficticia");
        action.addActionListener(event -> createPreview(frame, services));
        content.add(action, BorderLayout.SOUTH);

        frame.setContentPane(content);
        frame.pack();
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);
    }

    private static void createPreview(JFrame frame, ApplicationServices services) {
        try {
            var receipt = services.delivery().deliver(new DeliveryRequest(
                    "Aviso ficticio de demostración",
                    "Este documento no contiene datos reales y no se ha enviado por red.",
                    List.of()));
            JOptionPane.showMessageDialog(
                    frame,
                    "Vista previa creada en:\n" + receipt.previewFile(),
                    "Demostración completada",
                    JOptionPane.INFORMATION_MESSAGE);
        } catch (IOException error) {
            JOptionPane.showMessageDialog(
                    frame,
                    error.getMessage(),
                    "No se pudo crear la vista previa",
                    JOptionPane.ERROR_MESSAGE);
        }
    }
}
